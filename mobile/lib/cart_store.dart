import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SavedCart {
  const SavedCart({
    required this.items,
    this.saleType = 'retail',
    this.discount = '0',
    this.amountPaid = '',
    this.paymentMethod = 'cash',
    this.gcashTxnNo = '',
  });

  final List<CartItem> items;
  final String saleType;
  final String discount;
  final String amountPaid;
  final String paymentMethod;
  final String gcashTxnNo;

  static const empty = SavedCart(items: []);
}

class CartStore {
  static String _key(String userId) => 'ja_cart_$userId';

  static Future<SavedCart> load(String userId) async {
    if (userId.isEmpty) return SavedCart.empty;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return SavedCart.empty;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return SavedCart.empty;
      final items = ((parsed['cart'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.product.isNotEmpty && item.qty > 0)
          .toList();
      return SavedCart(
        items: items,
        saleType: parsed['saleType'] == 'wholesale' ? 'wholesale' : 'retail',
        discount: '${parsed['discount'] ?? '0'}',
        amountPaid: '${parsed['amountPaid'] ?? ''}',
        paymentMethod: parsed['paymentMethod'] == 'gcash' ? 'gcash' : 'cash',
        gcashTxnNo: '${parsed['gcashTxnNo'] ?? ''}',
      );
    } catch (_) {
      return SavedCart.empty;
    }
  }

  static Future<void> save(String userId, SavedCart cart) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode({
        'cart': cart.items.map((item) => item.toJson()).toList(),
        'saleType': cart.saleType,
        'discount': cart.discount,
        'amountPaid': cart.amountPaid,
        'paymentMethod': cart.paymentMethod,
        'gcashTxnNo': cart.gcashTxnNo,
      }),
    );
  }
}
