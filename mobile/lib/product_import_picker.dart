import 'dart:typed_data';

import 'product_import_picker_stub.dart'
    if (dart.library.html) 'product_import_picker_web.dart'
    if (dart.library.io) 'product_import_picker_io.dart' as impl;

Future<Uint8List?> pickProductImportBytes() => impl.pickProductImportBytes();
