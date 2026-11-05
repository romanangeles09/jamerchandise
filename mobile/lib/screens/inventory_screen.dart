import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../barcode_label.dart';
import '../bluetooth_printer.dart';
import '../code128.dart';
import '../layout.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';

String skuPrefix(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final word = parts.isEmpty || parts.first.isEmpty ? 'PRD' : parts.first;
  final letters = word.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  final base = letters.isEmpty ? 'PRD' : letters;
  return base.length >= 3 ? base.substring(0, 3) : base.padRight(3, 'X');
}

String nextSku(String categoryId, List<Product> products, List<Category> categories) {
  final category = categories.where((item) => item.id == categoryId).firstOrNull;
  if (category == null) return '';
  final prefix = skuPrefix(category.name);
  var max = 0;
  for (final product in products) {
    final sku = product.sku.toUpperCase();
    final match = RegExp('^$prefix-(\\d+)\$').firstMatch(sku);
    if (match == null) continue;
    final n = int.tryParse(match.group(1) ?? '') ?? 0;
    if (n > max) max = n;
  }
  return '$prefix-${(max + 1).toString().padLeft(3, '0')}';
}

String derivedCost(String wholesalePrice, String wholesaleMinQty) {
  final price = double.tryParse(wholesalePrice.trim());
  if (price == null || price < 0) return '';
  final qtyText = wholesaleMinQty.trim();
  final qty = qtyText.isEmpty ? 1 : int.tryParse(qtyText);
  if (qty == null || qty < 1) return '';
  final value = price * qty;
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String tab = 'products';
  List<Product> products = [];
  List<Category> categories = [];
  String query = '';
  String error = '';
  int page = 1;
  int pages = 1;
  int total = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int? nextPage}) async {
    try {
      final api = context.read<ApiClient>();
      final productPage = await api.products(page: nextPage ?? page, limit: 25, q: query);
      final cats = await api.categories();
      if (!mounted) return;
      setState(() {
        products = productPage.items;
        categories = cats;
        page = productPage.page;
        pages = productPage.pages;
        total = productPage.total;
        error = '';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load inventory.');
    }
  }

  List<Product> get filtered => products;

  Future<void> openProduct([Product? product]) async {
    await showJaDialog(
      context: context,
      title: product == null ? 'New product' : 'Edit product',
      width: isCompact(context) ? 520 : 640,
      child: _ProductForm(
        product: product,
        products: products,
        categories: categories,
        onSaved: load,
      ),
    );
  }

  Future<void> openCategory([Category? category]) async {
    await showJaDialog(
      context: context,
      title: category == null ? 'New category' : 'Edit category',
      child: _CategoryForm(category: category, onSaved: load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Row(
            children: [
              Expanded(
                child: SegmentedChoice(
                  value: tab,
                  options: const [('products', 'Products'), ('categories', 'Categories')],
                  onChanged: (value) => setState(() => tab = value),
                ),
              ),
              const SizedBox(width: 8),
              JaButton(
                label: tab == 'products' ? 'Add product' : 'Add category',
                primary: true,
                onPressed: () => tab == 'products' ? openProduct() : openCategory(),
              ),
            ],
          )
        else ...[
          PageHeader(
            eyebrow: 'Stock room',
            title: 'Inventory',
            trailing: JaButton(
              label: tab == 'products' ? 'Add product' : 'Add category',
              primary: true,
              onPressed: () => tab == 'products' ? openProduct() : openCategory(),
            ),
          ),
          SegmentedChoice(
            value: tab,
            options: const [('products', 'Products'), ('categories', 'Categories')],
            onChanged: (value) => setState(() => tab = value),
          ),
        ],
        SizedBox(height: compact ? 6 : 16),
        if (error.isNotEmpty) ...[JaAlert(error), SizedBox(height: compact ? 6 : 12)],
        if (tab == 'products') ...[
          TextField(
            decoration: InputDecoration(hintText: 'Search products', isDense: compact),
            onChanged: (value) {
              setState(() => query = value);
              Future<void>.delayed(const Duration(milliseconds: 250), () {
                if (!mounted || query != value) return;
                load(nextPage: 1);
              });
            },
          ),
          SizedBox(height: compact ? 6 : 16),
        ],
        Expanded(
          child: compact
              ? (tab == 'products' ? _productCards() : _categoryCards())
              : JaPanel(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: tab == 'products' ? _productTable() : _categoryTable(),
                  ),
                ),
        ),
        if (tab == 'products' && pages > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: page <= 1 ? null : () => load(nextPage: page - 1),
                child: const Text('Previous'),
              ),
              Expanded(
                child: Text(
                  'Page $page of $pages · $total total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: JaColors.muted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: page >= pages ? null : () => load(nextPage: page + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _productCards() {
    if (filtered.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Text('No products yet.', style: TextStyle(color: JaColors.muted)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = filtered[index];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: JaColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductPhoto(
                    name: product.name,
                    hasImage: product.hasImage,
                    imageUrl: product.imageUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [
                            if (product.alias.trim().isNotEmpty) product.alias,
                            product.category?.name ?? '',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: JaColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Retail ${peso(product.retailPrice)} · Stock ${product.stock} ${product.unit}',
                style: TextStyle(
                  color: product.stock <= product.reorderLevel ? JaColors.warn : JaColors.ink,
                  fontWeight: product.stock <= product.reorderLevel ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
              if (product.hasWholesale)
                Text(
                  'Wholesale ${peso(product.wholesalePrice)} · min ${product.wholesaleMin}',
                  style: const TextStyle(color: JaColors.muted, fontSize: 12),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  JaButton(label: 'Edit', onPressed: () => openProduct(product)),
                  const SizedBox(width: 8),
                  JaButton(
                    label: 'Delete',
                    onPressed: () async {
                      if (!await confirmAction(context, 'Delete this product?')) return;
                      if (!context.mounted) return;
                      await context.read<ApiClient>().deleteProduct(product.id);
                      await load();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryCards() {
    if (categories.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Text('No categories yet.', style: TextStyle(color: JaColors.muted)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = categories[index];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: JaColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                item.description.isEmpty ? 'No description' : item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: JaColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text('${item.productCount} products', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  JaButton(label: 'Edit', onPressed: () => openCategory(item)),
                  const SizedBox(width: 8),
                  JaButton(
                    label: 'Delete',
                    onPressed: () async {
                      if (!await confirmAction(context, 'Delete this category?')) return;
                      if (!context.mounted) return;
                      try {
                        await context.read<ApiClient>().deleteCategory(item.id);
                        await load();
                      } catch (err) {
                        setState(
                          () => error = err is ApiException ? err.message : 'Unable to delete category.',
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _productTable() {
    return JaTable(
      columns: const [
        DataColumn(label: Text('')),
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Retail')),
        DataColumn(label: Text('Wholesale')),
        DataColumn(label: Text('Stock')),
        DataColumn(label: Text('')),
      ],
      rows: filtered
          .map(
            (product) => DataRow(
              cells: [
                DataCell(
                  ProductPhoto(
                    name: product.name,
                    hasImage: product.hasImage,
                    imageUrl: product.imageUrl,
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (product.alias.trim().isNotEmpty)
                        Text(product.alias, style: const TextStyle(color: JaColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                DataCell(Text(product.category?.name ?? '')),
                DataCell(Text(peso(product.retailPrice))),
                DataCell(
                  Text(
                    product.hasWholesale
                        ? '${peso(product.wholesalePrice)}\nmin ${product.wholesaleMin}'
                        : '—',
                  ),
                ),
                DataCell(
                  Text(
                    '${product.stock} ${product.unit}',
                    style: TextStyle(
                      color: product.stock <= product.reorderLevel ? JaColors.warn : JaColors.ink,
                      fontWeight: product.stock <= product.reorderLevel ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      TextButton(onPressed: () => openProduct(product), child: const Text('Edit')),
                      TextButton(
                        onPressed: () async {
                          if (!await confirmAction(context, 'Delete this product?')) return;
                          if (!context.mounted) return;
                          await context.read<ApiClient>().deleteProduct(product.id);
                          await load();
                        },
                        child: const Text('Delete', style: TextStyle(color: JaColors.danger)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _categoryTable() {
    return JaTable(
      columns: const [
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Products')),
        DataColumn(label: Text('')),
      ],
      rows: categories
          .map(
            (item) => DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        item.description.isEmpty ? 'No description' : item.description,
                        style: const TextStyle(color: JaColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DataCell(Text('${item.productCount}')),
                DataCell(
                  Row(
                    children: [
                      TextButton(onPressed: () => openCategory(item), child: const Text('Edit')),
                      TextButton(
                        onPressed: () async {
                          if (!await confirmAction(context, 'Delete this category?')) return;
                          if (!context.mounted) return;
                          try {
                            await context.read<ApiClient>().deleteCategory(item.id);
                            await load();
                          } catch (err) {
                            setState(
                              () => error = err is ApiException
                                  ? err.message
                                  : 'Unable to delete category.',
                            );
                          }
                        },
                        child: const Text('Delete', style: TextStyle(color: JaColors.danger)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.products, required this.categories, required this.onSaved, this.product});

  final Product? product;
  final List<Product> products;
  final List<Category> categories;
  final Future<void> Function() onSaved;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late String category = widget.product?.category?.id ?? widget.categories.firstOrNull?.id ?? '';
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late final alias = TextEditingController(text: widget.product?.alias ?? '');
  late final sku = TextEditingController(
    text: widget.product?.sku ?? nextSku(category, widget.products, widget.categories),
  );
  late final barcode = TextEditingController(
    text: (widget.product?.barcode ?? '').isNotEmpty
        ? widget.product!.barcode
        : nextCode128Barcode(widget.products.map((item) => item.barcode)),
  );
  late final unit = TextEditingController(text: widget.product?.unit ?? 'pc');
  late final retail = TextEditingController(text: widget.product == null ? '' : '${widget.product!.retailPrice}');
  late final wholesale = TextEditingController(
    text: widget.product?.wholesalePrice == null ? '' : '${widget.product!.wholesalePrice}',
  );
  late final wholesaleMin = TextEditingController(
    text: widget.product?.wholesaleMinQty == null ? '' : '${widget.product!.wholesaleMinQty}',
  );
  late final cost = TextEditingController(
    text: derivedCost(
      widget.product?.wholesalePrice == null ? '' : '${widget.product!.wholesalePrice}',
      widget.product?.wholesaleMinQty == null ? '' : '${widget.product!.wholesaleMinQty}',
    ),
  );
  late final stock = TextEditingController(text: widget.product == null ? '' : '${widget.product!.stock}');
  late final barcodeCopies = TextEditingController(text: '1');
  bool isActive = true;
  bool saving = false;
  bool printingBarcode = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    isActive = widget.product?.isActive ?? true;
    wholesale.addListener(_syncCost);
    wholesaleMin.addListener(_syncCost);
    name.addListener(_refreshBarcodeLabel);
    retail.addListener(_refreshBarcodeLabel);
  }

  void _syncCost() {
    final next = derivedCost(wholesale.text, wholesaleMin.text);
    if (cost.text != next) cost.text = next;
  }

  void _refreshBarcodeLabel() {
    if (mounted) setState(() {});
  }

  void _syncSku() {
    if (widget.product != null) return;
    sku.text = nextSku(category, widget.products, widget.categories);
  }

  @override
  void dispose() {
    wholesale.removeListener(_syncCost);
    wholesaleMin.removeListener(_syncCost);
    name.removeListener(_refreshBarcodeLabel);
    retail.removeListener(_refreshBarcodeLabel);
    name.dispose();
    alias.dispose();
    sku.dispose();
    barcode.dispose();
    unit.dispose();
    retail.dispose();
    wholesale.dispose();
    wholesaleMin.dispose();
    cost.dispose();
    stock.dispose();
    barcodeCopies.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await context.read<ApiClient>().saveProduct(
        {
          'name': name.text,
          'alias': alias.text,
          'sku': sku.text,
          'barcode': barcode.text,
          'category': category,
          'unit': unit.text.isEmpty ? 'pc' : unit.text,
          'retailPrice': retail.text,
          'wholesalePrice': wholesale.text,
          'wholesaleMinQty': wholesaleMin.text,
          'costPrice': cost.text,
          'stock': stock.text.isEmpty ? '0' : stock.text,
          'reorderLevel': '${widget.product?.reorderLevel ?? 10}',
          'isActive': isActive ? 'true' : 'false',
        },
        id: widget.product?.id,
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => error = err is ApiException ? err.message : 'Unable to save product.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _pair(Widget left, Widget right) {
    if (isCompact(context)) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        _pair(
          FieldLabel(label: 'Name', child: TextField(controller: name)),
          FieldLabel(
            label: 'Alias',
            child: TextField(controller: alias, decoration: const InputDecoration(hintText: 'Optional')),
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Barcode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Code128Graphic(
                value: barcode.text,
                label: barcodeCaption(name.text, retail.text),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: isCompact(context) ? 84 : 96,
                    child: FieldLabel(
                      label: 'Copies',
                      child: TextField(
                        controller: barcodeCopies,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: JaButton(
                      label: printingBarcode ? 'Printing...' : 'Print barcode',
                      expanded: true,
                      icon: Icons.print,
                      onPressed: barcode.text.trim().isEmpty || printingBarcode
                          ? null
                          : () async {
                              setState(() {
                                error = '';
                                printingBarcode = true;
                              });
                              try {
                                await printBarcodeLabel(
                                  name: name.text,
                                  price: retail.text,
                                  barcode: barcode.text,
                                  copies: barcodeCopies.text,
                                );
                              } catch (err) {
                                if (!mounted) return;
                                setState(() {
                                  error = err is PrinterException ? err.message : 'Unable to print barcode.';
                                });
                              } finally {
                                if (mounted) setState(() => printingBarcode = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          FieldLabel(
            label: 'Category',
            child: DropdownButtonFormField<String>(
              initialValue: widget.categories.any((item) => item.id == category) ? category : null,
              items: widget.categories
                  .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              onChanged: (value) {
                setState(() => category = value ?? '');
                _syncSku();
              },
            ),
          ),
          FieldLabel(label: 'Unit', child: TextField(controller: unit)),
        ),
        const SizedBox(height: 12),
        _pair(
          FieldLabel(label: 'Stock', child: TextField(controller: stock, keyboardType: TextInputType.number)),
          FieldLabel(
            label: 'Retail price',
            child: TextField(controller: retail, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          FieldLabel(
            label: 'Wholesale price',
            child: TextField(
              controller: wholesale,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
          ),
          FieldLabel(
            label: 'Wholesale min qty',
            child: TextField(
              controller: wholesaleMin,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Cost',
          child: TextField(controller: cost, enabled: false, decoration: const InputDecoration(hintText: 'Auto')),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: isActive,
          onChanged: (value) => setState(() => isActive = value ?? true),
          title: const Text('Active in POS'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            JaButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            JaButton(label: saving ? 'Saving...' : 'Save product', primary: true, onPressed: saving ? null : save),
          ],
        ),
      ],
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({required this.onSaved, this.category});

  final Category? category;
  final Future<void> Function() onSaved;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final name = TextEditingController(text: widget.category?.name ?? '');
  late final description = TextEditingController(text: widget.category?.description ?? '');
  bool saving = false;
  String error = '';

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await context.read<ApiClient>().saveCategory(
        id: widget.category?.id,
        name: name.text,
        description: description.text,
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => error = err is ApiException ? err.message : 'Unable to save category.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        FieldLabel(label: 'Name', child: TextField(controller: name)),
        const SizedBox(height: 12),
        FieldLabel(label: 'Description', child: TextField(controller: description, maxLines: 3)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            JaButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            JaButton(label: saving ? 'Saving...' : 'Save category', primary: true, onPressed: saving ? null : save),
          ],
        ),
      ],
    );
  }
}
