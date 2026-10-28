import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
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

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<ApiClient>();
      final loaded = await Future.wait([api.products(), api.categories()]);
      if (!mounted) return;
      setState(() {
        products = loaded[0] as List<Product>;
        categories = loaded[1] as List<Category>;
        error = '';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load inventory.');
    }
  }

  List<Product> get filtered {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(term) ||
          product.sku.toLowerCase().contains(term) ||
          (product.category?.name.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  Future<void> openProduct([Product? product]) async {
    await showJaDialog(
      context: context,
      title: product == null ? 'New product' : 'Edit product',
      width: 640,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        if (tab == 'products') ...[
          TextField(
            decoration: const InputDecoration(hintText: 'Search products'),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: JaPanel(
            child: SingleChildScrollView(
              child: tab == 'products'
                  ? JaTable(
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
                                      Text(product.sku, style: const TextStyle(color: JaColors.muted, fontSize: 12)),
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
                    )
                  : JaTable(
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
                    ),
            ),
          ),
        ),
      ],
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
  late final sku = TextEditingController(
    text: widget.product?.sku ?? nextSku(category, widget.products, widget.categories),
  );
  late final barcode = TextEditingController(text: widget.product?.barcode ?? '');
  late final unit = TextEditingController(text: widget.product?.unit ?? 'pc');
  late final retail = TextEditingController(text: widget.product == null ? '' : '${widget.product!.retailPrice}');
  late final wholesale = TextEditingController(
    text: widget.product?.wholesalePrice == null ? '' : '${widget.product!.wholesalePrice}',
  );
  late final wholesaleMin = TextEditingController(
    text: widget.product?.wholesaleMinQty == null ? '' : '${widget.product!.wholesaleMinQty}',
  );
  late final cost = TextEditingController(
    text: widget.product?.costPrice == null
        ? derivedCost(
            widget.product?.wholesalePrice == null ? '' : '${widget.product!.wholesalePrice}',
            widget.product?.wholesaleMinQty == null ? '' : '${widget.product!.wholesaleMinQty}',
          )
        : '${widget.product!.costPrice}',
  );
  late final stock = TextEditingController(text: widget.product == null ? '' : '${widget.product!.stock}');
  bool isActive = true;
  File? imageFile;
  String previewUrl = '';
  bool removeImage = false;
  bool saving = false;
  String error = '';
  bool skuManual = false;
  bool costManual = false;

  @override
  void initState() {
    super.initState();
    isActive = widget.product?.isActive ?? true;
    previewUrl = widget.product?.imageUrl ?? '';
    skuManual = widget.product != null;
    costManual = widget.product?.costPrice != null;
    wholesale.addListener(_syncCost);
    wholesaleMin.addListener(_syncCost);
  }

  void _syncCost() {
    if (costManual) return;
    final next = derivedCost(wholesale.text, wholesaleMin.text);
    if (cost.text != next) cost.text = next;
  }

  @override
  void dispose() {
    wholesale.removeListener(_syncCost);
    wholesaleMin.removeListener(_syncCost);
    name.dispose();
    sku.dispose();
    barcode.dispose();
    unit.dispose();
    retail.dispose();
    wholesale.dispose();
    wholesaleMin.dispose();
    cost.dispose();
    stock.dispose();
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
          if (removeImage) 'removeImage': 'true',
        },
        id: widget.product?.id,
        image: imageFile,
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => error = err is ApiException ? err.message : 'Unable to save product.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        Row(
          children: [
            if (imageFile != null && !removeImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(imageFile!, width: 96, height: 96, fit: BoxFit.cover),
              )
            else
              ProductPhoto(
                name: name.text,
                hasImage: previewUrl.isNotEmpty && !removeImage,
                imageUrl: previewUrl,
                size: 96,
                radius: 16,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JaButton(
                    label: 'Choose photo',
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked == null) return;
                      setState(() {
                        imageFile = File(picked.path);
                        previewUrl = picked.path;
                        removeImage = false;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text('JPG, PNG, WEBP, or GIF up to 2 MB.', style: TextStyle(color: JaColors.muted, fontSize: 12)),
                  if (previewUrl.isNotEmpty && !removeImage)
                    TextButton(
                      onPressed: () => setState(() {
                        imageFile = null;
                        previewUrl = '';
                        removeImage = true;
                      }),
                      child: const Text('Remove photo', style: TextStyle(color: JaColors.danger)),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FieldLabel(label: 'Name', child: TextField(controller: name))),
            const SizedBox(width: 12),
            Expanded(
              child: FieldLabel(
                label: 'SKU',
                child: TextField(
                  controller: sku,
                  decoration: const InputDecoration(hintText: 'Auto'),
                  onChanged: (value) {
                    skuManual = value.trim().isNotEmpty;
                    if (!skuManual) {
                      sku.text = nextSku(category, widget.products, widget.categories);
                      sku.selection = TextSelection.collapsed(offset: sku.text.length);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FieldLabel(label: 'Barcode', child: TextField(controller: barcode))),
            const SizedBox(width: 12),
            Expanded(
              child: FieldLabel(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  initialValue: widget.categories.any((item) => item.id == category) ? category : null,
                  items: widget.categories
                      .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => category = value ?? '');
                    if (!skuManual) {
                      sku.text = nextSku(category, widget.products, widget.categories);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FieldLabel(label: 'Unit', child: TextField(controller: unit))),
            const SizedBox(width: 12),
            Expanded(child: FieldLabel(label: 'Stock', child: TextField(controller: stock, keyboardType: TextInputType.number))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FieldLabel(
                label: 'Retail price',
                child: TextField(controller: retail, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FieldLabel(
                label: 'Wholesale price',
                child: TextField(
                  controller: wholesale,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Optional'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FieldLabel(
                label: 'Wholesale min qty',
                child: TextField(
                  controller: wholesaleMin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Optional'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FieldLabel(
                label: 'Cost',
                child: TextField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Auto'),
                  onChanged: (value) {
                    costManual = value.trim().isNotEmpty;
                    if (!costManual) _syncCost();
                  },
                ),
              ),
            ),
          ],
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
