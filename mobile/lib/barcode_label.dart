import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'bluetooth_printer.dart';
import 'code128.dart';

int normalizeBarcodeCopies(Object? copies) {
  final parsed = copies is int ? copies : int.tryParse('$copies'.trim()) ?? 1;
  if (parsed < 1) return 1;
  if (parsed > 200) return 200;
  return parsed;
}

Future<void> printBarcodeLabel({
  required String name,
  required Object? price,
  required String barcode,
  Object? copies = 1,
}) async {
  final code = barcode.trim();
  if (code.isEmpty) return;
  final count = normalizeBarcodeCopies(copies);

  // Chrome / unsupported platforms: system PDF print.
  if (!BluetoothPrinter.isSupported) {
    await Printing.layoutPdf(
      name: 'JA barcode $code',
      onLayout: (_) => buildBarcodeLabelPdf(name: name, price: price, barcode: code, copies: count),
    );
    return;
  }

  try {
    // Send each label separately so thermal printers don't drop a big buffer.
    final ticket = await buildBarcodeLabelEscPos(name: name, price: price, barcode: code, copies: 1);
    for (var i = 0; i < count; i += 1) {
      await BluetoothPrinter.instance.printBytes(ticket);
      if (i < count - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  } catch (err) {
    // Windows desktop can fall back to the normal print dialog if Bluetooth fails.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await Printing.layoutPdf(
        name: 'JA barcode $code',
        onLayout: (_) => buildBarcodeLabelPdf(name: name, price: price, barcode: code, copies: count),
      );
      return;
    }
    rethrow;
  }
}

Future<List<int>> buildBarcodeLabelEscPos({
  required String name,
  required Object? price,
  required String barcode,
  int copies = 1,
}) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);
  final caption = barcodeCaption(name, price);
  final one = <int>[
    ...generator.reset(),
    ...generator.barcode(
      Barcode.code128('{B$barcode'.split('')),
      width: 2,
      height: 60,
      textPos: BarcodeText.none,
    ),
    ...generator.feed(1),
    ...generator.text(
      caption,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ),
    ...generator.feed(4),
  ];
  if (copies <= 1) return one;
  final bytes = <int>[];
  for (var i = 0; i < copies; i += 1) {
    bytes.addAll(one);
  }
  return bytes;
}

Future<Uint8List> buildBarcodeLabelPdf({
  required String name,
  required Object? price,
  required String barcode,
  int copies = 1,
}) async {
  final caption = barcodeCaption(name, price);
  final doc = pw.Document();
  for (var i = 0; i < copies; i += 1) {
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
              pw.BarcodeWidget(
                barcode: bc.Barcode.code128(),
                data: barcode,
                width: 46 * PdfPageFormat.mm,
                height: 14 * PdfPageFormat.mm,
                drawText: false,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                caption,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
            ],
          );
        },
      ),
    );
  }
  return doc.save();
}
