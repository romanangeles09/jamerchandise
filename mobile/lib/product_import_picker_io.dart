import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<Uint8List?> pickProductImportBytes() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls', 'csv']),
    ],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return bytes.isEmpty ? null : bytes;
}
