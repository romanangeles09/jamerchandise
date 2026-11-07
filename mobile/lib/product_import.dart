import 'dart:typed_data';

import 'package:excel/excel.dart';

class ProductImportRow {
  const ProductImportRow({required this.name, required this.price, required this.quantity});

  final String name;
  final double price;
  final int quantity;
}

class ProductImportParseResult {
  const ProductImportParseResult({required this.items, required this.skipped});

  final List<ProductImportRow> items;
  final List<String> skipped;
}

String _normalizeHeader(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');

String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  return value.toString().trim();
}

double? _parseNumber(Data? cell) {
  final raw = _cellText(cell).replaceAll(',', '').replaceAll('₱', '').replaceAll(RegExp(r'php', caseSensitive: false), '').trim();
  if (raw.isEmpty) return null;
  return double.tryParse(raw);
}

int _pickColumn(List<String> headers, List<String> aliases) {
  for (final alias in aliases) {
    final index = headers.indexWhere((header) => header == alias || header.contains(alias));
    if (index >= 0) return index;
  }
  return -1;
}

ProductImportParseResult parseProductImportBytes(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    throw Exception('Excel file has no sheets.');
  }
  final sheet = excel.tables[excel.tables.keys.first]!;
  if (sheet.rows.isEmpty) {
    throw Exception('Excel file is empty.');
  }

  final headerCells = sheet.rows.first;
  final headers = headerCells.map(_cellText).map(_normalizeHeader).toList();
  var nameIdx = _pickColumn(headers, const ['product name', 'name', 'item', 'item name']);
  var priceIdx = _pickColumn(headers, const ['retail price', 'price', 'amount']);
  var qtyIdx = _pickColumn(headers, const ['quantity', 'qty', 'stock', 'on hand']);
  var dataStart = 1;

  if (nameIdx < 0 || priceIdx < 0 || qtyIdx < 0) {
    final first = sheet.rows.first;
    final price = first.length > 1 ? _parseNumber(first[1]) : null;
    if (first.isNotEmpty && _cellText(first[0]).isNotEmpty && price != null) {
      nameIdx = 0;
      priceIdx = 1;
      qtyIdx = 2;
      dataStart = 0;
    } else {
      throw Exception('Need columns: "Product Name", "Price", and "Quantity".');
    }
  }

  final items = <ProductImportRow>[];
  final skipped = <String>[];

  for (var i = dataStart; i < sheet.rows.length; i += 1) {
    final row = sheet.rows[i];
    Data? at(int index) => index < row.length ? row[index] : null;
    final name = _cellText(at(nameIdx));
    final price = _parseNumber(at(priceIdx));
    final quantity = _parseNumber(at(qtyIdx));
    final excelRow = i + 1;

    if (name.isEmpty && price == null && quantity == null) continue;
    if (name.isEmpty) {
      skipped.add('Row $excelRow: missing product name.');
      continue;
    }
    if (price == null || price < 0) {
      skipped.add('Row $excelRow: invalid price.');
      continue;
    }
    if (quantity == null || quantity < 0 || quantity != quantity.roundToDouble()) {
      skipped.add('Row $excelRow: quantity must be a whole number.');
      continue;
    }

    items.add(ProductImportRow(name: name, price: price, quantity: quantity.round()));
  }

  return ProductImportParseResult(items: items, skipped: skipped);
}
