import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

Future<void> printSaleReceipt(Sale sale) {
  return Printing.layoutPdf(
    name: 'JA ${sale.invoiceNo}',
    onLayout: (_) => buildReceiptPdf(sale),
  );
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
            _kv('TICKET', sale.invoiceNo, base, bold),
            _kv('REGISTER', 'POS', base, bold),
            _kv('CASHIER', (sale.cashier?.name ?? '—').toUpperCase(), base, bold),
            _kv('TYPE', sale.saleType.toUpperCase(), base, bold),
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
            // pw.SizedBox(height: 6),
            // pw.Text('RETURNS ACCEPTED WITHIN', style: base, textAlign: pw.TextAlign.center),
            // pw.Text('30 DAYS WITH RECEIPT.', style: base, textAlign: pw.TextAlign.center),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _kv(String label, String value, pw.TextStyle base, pw.TextStyle bold) {
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
