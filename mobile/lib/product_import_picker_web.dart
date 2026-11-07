import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> pickProductImportBytes() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv';

  final completer = Completer<Uint8List?>();

  void finish(Uint8List? bytes) {
    if (!completer.isCompleted) completer.complete(bytes);
  }

  final cancelHandler = ((web.Event _) => finish(null)).toJS;
  input.addEventListener('cancel', cancelHandler);

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    final buffer = await file.arrayBuffer().toDart;
    finish(buffer.toDart.asUint8List());
  });

  input.click();
  try {
    return await completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => null,
    );
  } finally {
    input.removeEventListener('cancel', cancelHandler);
  }
}
