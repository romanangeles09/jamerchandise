import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'bluetooth_printer.dart';

Future<void> printBarcodeLabel({
  required String name,
  required String sku,
  required String barcode,
}) async {
  final code = barcode.trim();
  if (code.isEmpty) return;
  if (!BluetoothPrinter.isSupported) {
    await Printing.layoutPdf(
      name: 'JA barcode $code',
      onLayout: (_) => buildBarcodeLabelPdf(name: name, sku: sku, barcode: code),
    );
    return;
  }
  await BluetoothPrinter.instance.printBytes(
    await buildBarcodeLabelEscPos(name: name, sku: sku, barcode: code),
  );
}

Future<List<int>> buildBarcodeLabelEscPos({
  required String name,
  required String sku,
  required String barcode,
}) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final title = name.trim().isEmpty ? 'JA Merchandise' : name.trim();
  final bytes = <int>[
    ...generator.reset(),
    ...generator.text(
      title,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ),
    ...generator.barcode(
      Barcode.code128('{B$barcode'.split('')),
      width: 2,
      height: 60,
      textPos: BarcodeText.below,
    ),
  ];
  if (sku.trim().isNotEmpty) {
    bytes.addAll(generator.text(sku.trim(), styles: const PosStyles(align: PosAlign.center)));
  }
  bytes.addAll(generator.feed(3));
  return bytes;
}

Future<Uint8List> buildBarcodeLabelPdf({
  required String name,
  required String sku,
  required String barcode,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        50 * PdfPageFormat.mm,
        30 * PdfPageFormat.mm,
        marginAll: 1.6 * PdfPageFormat.mm,
      ),
      build: (context) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              name.trim().isEmpty ? 'JA Merchandise' : name.trim(),
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
            pw.SizedBox(height: 2),
            pw.BarcodeWidget(
              barcode: bc.Barcode.code128(),
              data: barcode,
              width: 46 * PdfPageFormat.mm,
              height: 14 * PdfPageFormat.mm,
              drawText: true,
              textStyle: const pw.TextStyle(fontSize: 8),
            ),
            if (sku.trim().isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Text(sku.trim(), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
          ],
        );
      },
    ),
  );
  return doc.save();
}
