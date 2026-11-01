import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'bluetooth_printer.dart';
import 'models.dart';
import 'money.dart';

const storeName = 'JA Merchandise';
const storeAddress = 'Bulakan, Bulacan';

String php(num? value) {
  return 'PHP ${NumberFormat('#,##0.00', 'en_US').format(value ?? 0)}';
}

String receiptDate(DateTime value) {
  return DateFormat('MM/dd/yyyy hh:mm a').format(toManila(value));
}

Future<void> printSaleReceipt(Sale sale) async {
  if (!BluetoothPrinter.isSupported) {
    await Printing.layoutPdf(
      name: 'JA ${sale.invoiceNo}',
      onLayout: (_) => buildReceiptPdf(sale),
    );
    return;
  }
  await BluetoothPrinter.instance.printBytes(await buildReceiptEscPos(sale));
}

Future<List<int>> buildReceiptEscPos(Sale sale) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final pay = sale.paymentMethod.toUpperCase();
  final bytes = <int>[
    ...generator.reset(),
    ...generator.text(
      storeName.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size1),
    ),
    ...generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center)),
    ...generator.feed(1),
    ...generator.text(receiptDate(sale.createdAt), styles: const PosStyles(align: PosAlign.center, bold: true)),
    ...generator.feed(1),
    ...generator.text(_kv('TICKET', sale.invoiceNo)),
    ...generator.text(_kv('REGISTER', 'POS')),
    ...generator.text(_kv('CASHIER', (sale.cashier?.name ?? '—').toUpperCase())),
    ...generator.text(_kv('TYPE', sale.saleType.toUpperCase())),
    ...generator.hr(),
  ];

  for (final item in sale.items) {
    bytes.addAll(generator.text(
      _twoCol('${item.qty}X ${item.name.toUpperCase()}', php(item.lineTotal)),
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text('${item.sku}  ${php(item.unitPrice)}'));
  }

  bytes.addAll(generator.hr());
  bytes.addAll(generator.text(_twoCol('SUBTOTAL:', php(sale.subtotal))));
  bytes.addAll(generator.text(_twoCol('DISCOUNT:', php(sale.discount))));
  bytes.addAll(generator.text(_twoCol('TOTAL:', php(sale.total)), styles: const PosStyles(bold: true)));
  bytes.addAll(generator.text(_twoCol('$pay:', php(sale.amountPaid))));
  if (sale.paymentMethod.toLowerCase() == 'gcash' && sale.gcashTxnNo.isNotEmpty) {
    bytes.addAll(generator.text(_twoCol('GCASH TXN:', sale.gcashTxnNo)));
  }
  bytes.addAll(generator.text(_twoCol('CHANGE:', php(sale.change))));
  bytes.addAll(generator.hr());
  bytes.addAll(generator.text('VISIT AGAIN SOON!', styles: const PosStyles(align: PosAlign.center, bold: true)));
  bytes.addAll(generator.feed(3));
  return bytes;
}

String _kv(String label, String value) {
  final left = '$label:'.padRight(10);
  return '$left$value';
}

String _twoCol(String left, String right, [int width = 32]) {
  if (left.length + right.length >= width) {
    final maxLeft = width - right.length - 1;
    if (maxLeft < 1) return right.padLeft(width);
    final clipped = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    return '$clipped $right';
  }
  return left + ' ' * (width - left.length - right.length) + right;
}

Future<Uint8List> buildReceiptPdf(Sale sale) async {
  final doc = pw.Document();
  final base = pw.TextStyle(font: pw.Font.courier(), fontSize: 9, lineSpacing: 1.2);
  final bold = pw.TextStyle(font: pw.Font.courierBold(), fontSize: 9, lineSpacing: 1.2);
  final title = pw.TextStyle(font: pw.Font.courierBold(), fontSize: 12, lineSpacing: 1.1);
  final pay = sale.paymentMethod.toUpperCase();

  final heightMm = (110 + sale.items.length * 16).clamp(140, 500).toDouble();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        heightMm * PdfPageFormat.mm,
        marginAll: 5 * PdfPageFormat.mm,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(storeName.toUpperCase(), style: title, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(storeAddress, style: base, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            pw.Text(receiptDate(sale.createdAt), style: bold, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
            _pdfKv('TICKET', sale.invoiceNo, base, bold),
            _pdfKv('REGISTER', 'POS', base, bold),
            _pdfKv('CASHIER', (sale.cashier?.name ?? '—').toUpperCase(), base, bold),
            _pdfKv('TYPE', sale.saleType.toUpperCase(), base, bold),
            pw.SizedBox(height: 8),
            pw.Text('-' * 32, style: base, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            ...sale.items.map((item) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _amountRow('${item.qty}X ${item.name.toUpperCase()}', php(item.lineTotal), bold),
                    pw.Text(
                      '${item.sku}  ${php(item.unitPrice)}',
                      style: base,
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 4),
            pw.Text('-' * 32, style: base, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 6),
            _amountRow('SUBTOTAL:', php(sale.subtotal), base),
            _amountRow('DISCOUNT:', php(sale.discount), base),
            _amountRow('TOTAL:', php(sale.total), bold),
            pw.SizedBox(height: 6),
            _amountRow('$pay:', php(sale.amountPaid), base),
            if (sale.paymentMethod.toLowerCase() == 'gcash' && sale.gcashTxnNo.isNotEmpty)
              _amountRow('GCASH TXN:', sale.gcashTxnNo, base),
            _amountRow('CHANGE:', php(sale.change), base),
            pw.SizedBox(height: 12),
            pw.Text('-' * 32, style: base, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
            pw.Text('VISIT AGAIN SOON!', style: bold, textAlign: pw.TextAlign.center),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _pdfKv(String label, String value, pw.TextStyle base, pw.TextStyle bold) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(width: 72, child: pw.Text('$label:', style: base)),
      pw.Expanded(child: pw.Text(value, style: bold)),
    ],
  );
}

pw.Widget _amountRow(String label, String amount, pw.TextStyle style) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: pw.Text(label, style: style)),
      pw.Text(amount, style: style),
    ],
  );
}
