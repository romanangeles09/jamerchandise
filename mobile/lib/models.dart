String jsonId(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) return jsonId(value['_id'] ?? value['id']);
  return value.toString();
}

double jsonNum(dynamic value) {
  if (value == null || value == '') return 0;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int jsonInt(dynamic value) => jsonNum(value).round();

double? jsonNumOrNull(dynamic value) {
  if (value == null || value == '') return null;
  return jsonNum(value);
}

int? jsonIntOrNull(dynamic value) {
  if (value == null || value == '') return null;
  return jsonInt(value);
}

DateTime jsonDate(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse('$value') ?? DateTime.now();
}

class NamedRef {
  const NamedRef({required this.id, required this.name});

  final String id;
  final String name;

  factory NamedRef.fromJson(dynamic json) {
    if (json is Map) {
      return NamedRef(id: jsonId(json), name: '${json['name'] ?? ''}');
    }
    return NamedRef(id: jsonId(json), name: '');
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.access,
    required this.isActive,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> access;
  final bool isActive;
  final String avatarUrl;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: jsonId(json),
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? 'Cashier'}',
      access: ((json['access'] as List?) ?? const []).map((item) => '$item').toList(),
      isActive: json['isActive'] != false,
      avatarUrl: '${json['avatarUrl'] ?? ''}',
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.description = '',
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final int productCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: jsonId(json),
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      productCount: jsonInt(json['productCount']),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.retailPrice,
    required this.stock,
    required this.reorderLevel,
    required this.isActive,
    required this.hasImage,
    required this.imageUrl,
    this.category,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.costPrice,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;
  final NamedRef? category;
  final String unit;
  final double retailPrice;
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  final double? costPrice;
  final int stock;
  final int reorderLevel;
  final bool isActive;
  final bool hasImage;
  final String imageUrl;
  final DateTime? updatedAt;

  bool get hasWholesale => (wholesalePrice ?? 0) > 0;
  int get wholesaleMin => (wholesaleMinQty ?? 0) > 0 ? wholesaleMinQty! : 1;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: jsonId(json),
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      barcode: '${json['barcode'] ?? ''}',
      category: json['category'] == null ? null : NamedRef.fromJson(json['category']),
      unit: '${json['unit'] ?? 'pc'}',
      retailPrice: jsonNum(json['retailPrice']),
      wholesalePrice: jsonNumOrNull(json['wholesalePrice']),
      wholesaleMinQty: jsonIntOrNull(json['wholesaleMinQty']),
      costPrice: jsonNumOrNull(json['costPrice']),
      stock: jsonInt(json['stock']),
      reorderLevel: jsonInt(json['reorderLevel'] ?? 10),
      isActive: json['isActive'] != false,
      hasImage: json['hasImage'] == true || '${json['imageUrl'] ?? ''}'.isNotEmpty,
      imageUrl: '${json['imageUrl'] ?? ''}',
      updatedAt: json['updatedAt'] == null ? null : jsonDate(json['updatedAt']),
    );
  }
}

class SaleItem {
  const SaleItem({
    required this.name,
    required this.sku,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final String sku;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      qty: jsonInt(json['qty']),
      unitPrice: jsonNum(json['unitPrice']),
      lineTotal: jsonNum(json['lineTotal']),
    );
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.saleType,
    required this.paymentMethod,
    this.gcashTxnNo = '',
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.change,
    required this.createdAt,
    this.cashier,
  });

  final String id;
  final String invoiceNo;
  final String saleType;
  final String paymentMethod;
  final String gcashTxnNo;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final double amountPaid;
  final double change;
  final NamedRef? cashier;
  final DateTime createdAt;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: jsonId(json),
      invoiceNo: '${json['invoiceNo'] ?? ''}',
      saleType: '${json['saleType'] ?? 'retail'}',
      paymentMethod: '${json['paymentMethod'] ?? 'cash'}',
      gcashTxnNo: '${json['gcashTxnNo'] ?? ''}',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => SaleItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      subtotal: jsonNum(json['subtotal']),
      discount: jsonNum(json['discount']),
      total: jsonNum(json['total']),
      amountPaid: jsonNum(json['amountPaid']),
      change: jsonNum(json['change']),
      cashier: json['cashier'] == null ? null : NamedRef.fromJson(json['cashier']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}

class DayPoint {
  const DayPoint({required this.date, required this.revenue});

  final String date;
  final double revenue;

  factory DayPoint.fromJson(Map<String, dynamic> json) {
    return DayPoint(date: '${json['date'] ?? ''}', revenue: jsonNum(json['revenue']));
  }
}

class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.label,
    required this.revenue,
    required this.sales,
  });

  final int month;
  final String label;
  final double revenue;
  final int sales;

  factory MonthPoint.fromJson(Map<String, dynamic> json) {
    return MonthPoint(
      month: jsonInt(json['month']),
      label: '${json['label'] ?? ''}',
      revenue: jsonNum(json['revenue']),
      sales: jsonInt(json['sales']),
    );
  }
}

class TodayStats {
  const TodayStats({
    required this.revenue,
    required this.sales,
    required this.retail,
    required this.wholesale,
  });

  final double revenue;
  final int sales;
  final double retail;
  final double wholesale;

  factory TodayStats.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return TodayStats(
      revenue: jsonNum(json['revenue']),
      sales: jsonInt(json['sales']),
      retail: jsonNum(json['retail']),
      wholesale: jsonNum(json['wholesale']),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.today,
    required this.productCount,
    required this.categoryCount,
    required this.weekly,
    required this.monthly,
    required this.years,
    required this.year,
    required this.lowStock,
    required this.recentSales,
  });

  final TodayStats today;
  final int productCount;
  final int categoryCount;
  final List<DayPoint> weekly;
  final List<MonthPoint> monthly;
  final List<int> years;
  final int year;
  final List<Product> lowStock;
  final List<Sale> recentSales;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      today: TodayStats.fromJson(json['today'] as Map<String, dynamic>?),
      productCount: jsonInt(json['productCount']),
      categoryCount: jsonInt(json['categoryCount']),
      weekly: ((json['weekly'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => DayPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      monthly: ((json['monthly'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MonthPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      years: ((json['years'] as List?) ?? const []).map(jsonInt).toList(),
      year: jsonInt(json['year']),
      lowStock: ((json['lowStock'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      recentSales: ((json['recentSales'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Sale.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class SummaryStats {
  const SummaryStats({
    required this.tickets,
    required this.itemCount,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cash,
    required this.gcash,
    required this.retail,
    required this.wholesale,
  });

  final int tickets;
  final int itemCount;
  final double subtotal;
  final double discount;
  final double total;
  final double cash;
  final double gcash;
  final double retail;
  final double wholesale;

  factory SummaryStats.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return SummaryStats(
      tickets: jsonInt(json['tickets']),
      itemCount: jsonInt(json['itemCount']),
      subtotal: jsonNum(json['subtotal']),
      discount: jsonNum(json['discount']),
      total: jsonNum(json['total']),
      cash: jsonNum(json['cash']),
      gcash: jsonNum(json['gcash']),
      retail: jsonNum(json['retail']),
      wholesale: jsonNum(json['wholesale']),
    );
  }
}

class SoldProduct {
  const SoldProduct({
    required this.name,
    required this.sku,
    required this.qty,
    required this.amount,
  });

  final String name;
  final String sku;
  final int qty;
  final double amount;

  factory SoldProduct.fromJson(Map<String, dynamic> json) {
    return SoldProduct(
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      qty: jsonInt(json['qty']),
      amount: jsonNum(json['amount']),
    );
  }
}

class CashierRow {
  const CashierRow({required this.name, required this.tickets, required this.total});

  final String name;
  final int tickets;
  final double total;

  factory CashierRow.fromJson(Map<String, dynamic> json) {
    return CashierRow(
      name: '${json['name'] ?? ''}',
      tickets: jsonInt(json['tickets']),
      total: jsonNum(json['total']),
    );
  }
}

class MonthDetail {
  const MonthDetail({
    required this.year,
    required this.month,
    required this.label,
    required this.summary,
    required this.products,
    required this.cashiers,
    required this.sales,
  });

  final int year;
  final int month;
  final String label;
  final SummaryStats summary;
  final List<SoldProduct> products;
  final List<CashierRow> cashiers;
  final List<Sale> sales;

  factory MonthDetail.fromJson(Map<String, dynamic> json) {
    return MonthDetail(
      year: jsonInt(json['year']),
      month: jsonInt(json['month']),
      label: '${json['label'] ?? ''}',
      summary: SummaryStats.fromJson(json['summary'] as Map<String, dynamic>?),
      products: ((json['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => SoldProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      cashiers: ((json['cashiers'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => CashierRow.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      sales: ((json['sales'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Sale.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class CutoffCashier {
  const CutoffCashier({required this.id, required this.name});

  final String id;
  final String name;

  factory CutoffCashier.fromJson(Map<String, dynamic> json) {
    return CutoffCashier(id: jsonId(json), name: '${json['name'] ?? ''}');
  }
}

class CutoffReport {
  const CutoffReport({
    required this.summary,
    required this.products,
    required this.sales,
    required this.cashiers,
    required this.canPickCashier,
  });

  final SummaryStats summary;
  final List<SoldProduct> products;
  final List<Sale> sales;
  final List<CutoffCashier> cashiers;
  final bool canPickCashier;

  factory CutoffReport.fromJson(Map<String, dynamic> json) {
    return CutoffReport(
      summary: SummaryStats.fromJson(json['summary'] as Map<String, dynamic>?),
      products: ((json['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => SoldProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      sales: ((json['sales'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Sale.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      cashiers: ((json['cashiers'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => CutoffCashier.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      canPickCashier: json['canPickCashier'] == true,
    );
  }
}

class CartItem {
  CartItem({
    required this.product,
    required this.name,
    required this.sku,
    required this.unit,
    required this.stock,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.qty,
  });

  final String product;
  final String name;
  final String sku;
  final String unit;
  final int stock;
  final double retailPrice;
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  int qty;

  factory CartItem.fromProduct(Product product, int qty) {
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
  }
}
