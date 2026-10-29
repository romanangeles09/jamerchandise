import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../cart_store.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scanner_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final search = TextEditingController();
  final discountInput = TextEditingController(text: '0');
  final paidInput = TextEditingController();
  final gcashTxnNo = TextEditingController();
  List<Product> products = [];
  List<Category> categories = [];
  List<CartItem> cart = [];
  String category = '';
  String saleType = 'retail';
  String paymentMethod = 'cash';
  String error = '';
  String scanNotice = '';
  bool busy = false;
  bool cartReady = false;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    discountInput.addListener(() {
      setState(() {});
      rememberCart();
    });
    paidInput.addListener(() {
      setState(() {});
      rememberCart();
    });
    gcashTxnNo.addListener(rememberCart);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    discountInput.dispose();
    paidInput.dispose();
    gcashTxnNo.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final api = context.read<ApiClient>();
      final loaded = await Future.wait([api.products(active: true), api.categories()]);
      if (!mounted) return;
      setState(() {
        products = loaded[0] as List<Product>;
        categories = loaded[1] as List<Category>;
      });
      if (!cartReady) {
        await restoreCart();
      } else {
        setState(() => cart = syncCartWithProducts(cart));
        await rememberCart();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load POS catalog.');
    }
  }

  List<Product> get visible {
    final term = search.text.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory = category.isEmpty || product.category?.id == category;
      final matchesQuery =
          term.isEmpty ||
          product.name.toLowerCase().contains(term) ||
          product.sku.toLowerCase().contains(term) ||
          product.barcode.toLowerCase().contains(term);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  List<CartItem> syncCartWithProducts(List<CartItem> items) {
    return items
        .map((item) {
          final product = products.where((row) => row.id == item.product).firstOrNull;
          if (product == null) return item;
          final minQty = saleType == 'wholesale' ? product.wholesaleMin : 1;
          final qty = product.stock < minQty ? 0 : item.qty.clamp(minQty, product.stock);
          return CartItem(
            product: product.id,
            name: product.name,
            sku: product.sku,
            unit: product.unit,
            stock: product.stock,
            retailPrice: product.retailPrice,
            wholesalePrice: product.wholesalePrice,
            wholesaleMinQty: product.wholesaleMinQty,
            qty: qty,
          );
        })
        .where((item) => item.qty > 0)
        .toList();
  }

  Future<void> restoreCart() async {
    final userId = context.read<AuthController>().user?.id ?? '';
    if (userId.isEmpty) {
      setState(() => cartReady = true);
      return;
    }
    final saved = await CartStore.load(userId);
    if (!mounted) return;
    setState(() {
      saleType = saved.saleType;
      paymentMethod = saved.paymentMethod;
      discountInput.text = saved.discount.isEmpty ? '0' : saved.discount;
      paidInput.text = saved.amountPaid;
      gcashTxnNo.text = saved.gcashTxnNo;
      cart = syncCartWithProducts(saved.items);
      cartReady = true;
    });
    await rememberCart();
  }

  Future<void> rememberCart() async {
    if (!cartReady || !mounted) return;
    final userId = context.read<AuthController>().user?.id ?? '';
    if (userId.isEmpty) return;
    await CartStore.save(
      userId,
      SavedCart(
        items: cart,
        saleType: saleType,
        discount: discountInput.text,
        amountPaid: paidInput.text,
        paymentMethod: paymentMethod,
        gcashTxnNo: gcashTxnNo.text,
      ),
    );
  }

  double priceOf(Product product) {
    return saleType == 'wholesale' && product.hasWholesale ? product.wholesalePrice! : product.retailPrice;
  }

  double unitPrice(CartItem item) {
    return saleType == 'wholesale' && (item.wholesalePrice ?? 0) > 0 ? item.wholesalePrice! : item.retailPrice;
  }

  double get subtotal => cart.fold(0, (sum, item) => sum + unitPrice(item) * item.qty);
  double get discount => (double.tryParse(discountInput.text) ?? 0).clamp(0, subtotal);
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get paid => double.tryParse(paidInput.text) ?? double.nan;
  double get change => paid.isNaN ? 0 : paid - total;

  String normalizeCode(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
  }

  Product? findByCode(String code) {
    final term = code.trim().toLowerCase();
    final compact = normalizeCode(code);
    if (compact.isEmpty) return null;
    for (final product in products) {
      final barcode = product.barcode.toLowerCase();
      final sku = product.sku.toLowerCase();
      if (barcode == term ||
          sku == term ||
          normalizeCode(product.barcode) == compact ||
          normalizeCode(product.sku) == compact) {
        return product;
      }
    }
    return null;
  }

  bool addProduct(Product product) {
    if (saleType == 'wholesale' && !product.hasWholesale) {
      setState(() => error = '${product.name} is not available for wholesale.');
      return false;
    }
    final minQty = saleType == 'wholesale' ? product.wholesaleMin : 1;
    final existing = cart.where((item) => item.product == product.id).firstOrNull;
    final nextQty = existing == null ? minQty : existing.qty + 1;
    if (nextQty > product.stock) {
      setState(() => error = 'Not enough stock for ${product.name}.');
      return false;
    }
    setState(() {
      error = '';
      if (existing != null) {
        existing.qty += 1;
      } else {
        cart = [...cart, CartItem.fromProduct(product, minQty)];
      }
    });
    rememberCart();
    return true;
  }

  ScanResult addByCode(String code) {
    final product = findByCode(code);
    if (product == null) {
      setState(() {
        error = 'No product found for $code.';
        scanNotice = '';
      });
      return ScanResult(code: code, added: false, message: 'No product found for $code.');
    }
    final added = addProduct(product);
    if (added) {
      setState(() {
        scanNotice = 'Added ${product.name}';
        error = '';
        search.clear();
      });
      return ScanResult(code: code, added: true, message: 'Added ${product.name}');
    }
    return ScanResult(code: code, added: false, message: error.isEmpty ? 'Could not add $code.' : error);
  }

  void updateQty(String id, int qty) {
    setState(() {
      cart = cart.map((item) {
        if (item.product != id) return item;
        final minQty = saleType == 'wholesale' ? ((item.wholesaleMinQty ?? 0) > 0 ? item.wholesaleMinQty! : 1) : 1;
        item.qty = qty.clamp(minQty, item.stock);
        return item;
      }).toList();
    });
    rememberCart();
  }

  void removeCartItem(String id) {
    setState(() => cart = cart.where((row) => row.product != id).toList());
    rememberCart();
  }

  Future<void> requestRemove(CartItem item) async {
    if (context.read<AuthController>().user?.role == 'SuperAdmin') {
      removeCartItem(item.product);
      return;
    }
    final ok = await confirmVoidWithPin(
      context,
      itemName: item.name,
      verify: (pin) => context.read<ApiClient>().verifySuperAdminPin(pin),
    );
    if (ok && mounted) removeCartItem(item.product);
  }

  void adjustQty(String id, int delta) {
    final item = cart.where((row) => row.product == id).firstOrNull;
    if (item == null) return;
    final minQty = saleType == 'wholesale' ? ((item.wholesaleMinQty ?? 0) > 0 ? item.wholesaleMinQty! : 1) : 1;
    final next = item.qty + delta;
    if (next < minQty) {
      setState(() => cart = cart.where((row) => row.product != id).toList());
      rememberCart();
      return;
    }
    updateQty(id, next);
  }

  Future<void> checkout() async {
    if (cart.isEmpty) {
      setState(() => error = 'Add items before checkout.');
      return;
    }
    if (paid.isNaN || paid < total) {
      setState(() => error = 'Amount paid must cover the total.');
      return;
    }
    if (paymentMethod == 'gcash' && gcashTxnNo.text.trim().isEmpty) {
      setState(() => error = 'GCash Txn No. is required.');
      return;
    }
    final confirmed = await confirmAction(context, 'Are you sure you want to complete this sale?');
    if (!confirmed || !mounted) return;
    setState(() {
      error = '';
      busy = true;
    });
    try {
      final receipt = await context.read<ApiClient>().createSale({
        'saleType': saleType,
        'discount': discount,
        'amountPaid': paid,
        'paymentMethod': paymentMethod,
        'gcashTxnNo': paymentMethod == 'gcash' ? gcashTxnNo.text.trim() : '',
        'items': cart.map((item) => {'product': item.product, 'qty': item.qty}).toList(),
      });
      if (!mounted) return;
      setState(() {
        cart = [];
        discountInput.text = '0';
        paidInput.clear();
        gcashTxnNo.clear();
      });
      await rememberCart();
      await load();
      if (!mounted) return;
      await showJaDialog(
        context: context,
        title: 'Ticket ${receipt.invoiceNo}',
        child: TicketBody(sale: receipt, actionLabel: 'New sale'),
      );
    } catch (err) {
      setState(() => error = err is ApiException ? err.message : 'Checkout failed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openScanner() async {
    setState(() {
      scanNotice = '';
      error = '';
    });
    await openBarcodeScanner(
      context: context,
      onScan: addByCode,
      cartItems: () => cart,
      unitPrice: unitPrice,
      onAdjustQty: adjustQty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Register',
                title: 'Point of sale',
                trailing: SegmentedChoice(
                  value: saleType,
                  options: const [('retail', 'Retail'), ('wholesale', 'Wholesale')],
                  onChanged: (value) {
                    setState(() => saleType = value);
                    rememberCart();
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      decoration: const InputDecoration(hintText: 'Search name, SKU, or barcode'),
                      onSubmitted: (value) {
                        if (findByCode(value) != null) addByCode(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  JaButton(
                    label: 'Scan barcode',
                    icon: Icons.qr_code_scanner,
                    onPressed: openScanner,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  ChipChoice(label: 'All', selected: category.isEmpty, onTap: () => setState(() => category = '')),
                  ...categories.map(
                    (item) => ChipChoice(
                      label: item.name,
                      selected: category == item.id,
                      onTap: () => setState(() => category = item.id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 148,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    final disabled = product.stock < 1 || (saleType == 'wholesale' && !product.hasWholesale);
                    return Opacity(
                      opacity: disabled ? 0.45 : 1,
                      child: InkWell(
                        onTap: disabled ? null : () => addProduct(product),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: JaColors.card,
                            border: Border.all(color: JaColors.line),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final side = constraints.biggest.shortestSide;
                                    return ProductPhoto(
                                      name: product.name,
                                      hasImage: product.hasImage,
                                      imageUrl: product.imageUrl,
                                      size: side,
                                      radius: 10,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                product.category?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: JaColors.muted, fontSize: 11),
                              ),
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                peso(priceOf(product)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: JaColors.copperDark, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                '${product.stock} ${product.unit}${saleType == 'wholesale' && product.hasWholesale ? ' · min ${product.wholesaleMin}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: JaColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 300,
          child: JaPanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cart', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 8)],
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (cart.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('Tap a product to add it.', style: TextStyle(color: JaColors.muted)),
                        )
                      else
                        ...cart.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(
                                        '${peso(unitPrice(item))} / ${item.unit}',
                                        style: const TextStyle(color: JaColors.muted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                _qtyButton(Icons.remove, () => updateQty(item.product, item.qty - 1)),
                                Text('${item.qty}', style: const TextStyle(fontSize: 13)),
                                _qtyButton(Icons.add, () => updateQty(item.product, item.qty + 1)),
                                _qtyButton(
                                  Icons.delete_outline,
                                  () => requestRemove(item),
                                  color: JaColors.danger,
                                ),
                                SizedBox(
                                  width: 64,
                                  child: Text(peso(unitPrice(item) * item.qty), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          );
                        }),
                      FieldLabel(
                        label: 'Discount',
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: discountInput,
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FieldLabel(
                        label: 'Payment',
                        child: DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                          ],
                          onChanged: (value) {
                            setState(() => paymentMethod = value ?? 'cash');
                            if (value != 'gcash') gcashTxnNo.clear();
                            rememberCart();
                          },
                        ),
                      ),
                      if (paymentMethod == 'gcash') ...[
                        const SizedBox(height: 8),
                        FieldLabel(
                          label: 'GCash Txn No.',
                          child: TextField(
                            controller: gcashTxnNo,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      FieldLabel(
                        label: 'Amount paid',
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: InputDecoration(isDense: true, hintText: total == 0 ? '' : '$total'),
                          controller: paidInput,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _row('Subtotal', peso(subtotal)),
                      _row('Discount', peso(discount)),
                      _row('Total', peso(total), bold: true),
                      _row('Change', peso(change < 0 ? 0 : change)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                JaButton(
                  label: busy ? 'Saving...' : 'Complete sale',
                  primary: true,
                  expanded: true,
                  onPressed: busy ? null : checkout,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 16, color: color),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 16 : 13)),
        ],
      ),
    );
  }
}
