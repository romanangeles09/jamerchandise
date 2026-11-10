import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PairedPrinter {
  const PairedPrinter({required this.name, required this.mac});

  final String name;
  final String mac;
}

class BluetoothPrinter {
  BluetoothPrinter._();
  static final instance = BluetoothPrinter._();

  static const _macKey = 'ja_bt_printer_mac';
  static const _nameKey = 'ja_bt_printer_name';

  String mac = '';
  String name = '';

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    mac = prefs.getString(_macKey) ?? '';
    name = prefs.getString(_nameKey) ?? '';
  }

  Future<void> remember(String nextMac, String nextName) async {
    mac = nextMac;
    name = nextName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, nextMac);
    await prefs.setString(_nameKey, nextName);
  }

  Future<bool> get isConnected async {
    if (!isSupported) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  Future<List<PairedPrinter>> pairedPrinters() async {
    if (!isSupported) return const [];
    await _ensureReady();
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((item) => PairedPrinter(name: item.name, mac: item.macAdress))
        .where((item) => item.mac.isNotEmpty)
        .toList();
  }

  Future<void> usePrinter(PairedPrinter printer) async {
    await _connectTo(printer.mac, printer.name, force: true);
  }

  Future<void> printBytes(List<int> bytes) async {
    if (!isSupported) {
      throw PrinterException('Bluetooth printing is only available in the tablet app.');
    }

    // Android RFCOMM sockets drop often; reconnect right before every job.
    await ensureConnected(forceReconnect: _isAndroid);

    var ok = await _write(bytes);
    if (!ok) {
      await ensureConnected(forceReconnect: true);
      ok = await _write(bytes);
    }
    if (!ok) {
      throw PrinterException('Printer did not accept the job. Check paper and power, then try again.');
    }
  }

  Future<bool> _write(List<int> bytes) async {
    try {
      return await PrintBluetoothThermal.writeBytes(bytes);
    } on PlatformException catch (error) {
      if (_isPermissionError(error)) {
        throw PrinterException(
          'Allow Nearby devices / Bluetooth for JA Merchandise, then try again.',
        );
      }
      return false;
    }
  }

  Future<void> printTest() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[
      ...generator.reset(),
      ...generator.text(
        'JA MERCHANDISE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...generator.text(
        'GOOJPRT printer ready',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.feed(3),
    ];
    await printBytes(bytes);
  }

  Future<void> ensureConnected({bool forceReconnect = false}) async {
    if (!isSupported) {
      throw PrinterException('Bluetooth printing is only available in the tablet app.');
    }
    await loadSaved();
    await _ensureReady();

    if (!forceReconnect && mac.isNotEmpty) {
      // Avoid Android connectionStatus probe (it writes a space and can break the socket).
      if (!_isAndroid && await isConnected) return;
    }

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (devices.isEmpty) {
      throw PrinterException(
        'Pair the GOOJPRT printer in Bluetooth settings first (PIN 0000 or 1234), then print again.',
      );
    }

    BluetoothInfo? target;
    if (mac.isNotEmpty) {
      for (final device in devices) {
        if (device.macAdress.toUpperCase() == mac.toUpperCase()) {
          target = device;
          break;
        }
      }
    }
    target ??= _pickGoojprt(devices);
    if (target == null) {
      final names = devices.map((item) => item.name.trim()).where((item) => item.isNotEmpty).join(', ');
      throw PrinterException(
        names.isEmpty
            ? 'No receipt printer found among paired Bluetooth devices. Open Account Setting and tap XP-58H or PT265.'
            : 'Open Account Setting and tap your printer (XP-58H / PT265). Paired: $names',
      );
    }
    await _connectTo(target.macAdress, target.name, force: true);
  }

  Future<void> _connectTo(String nextMac, String nextName, {bool force = false}) async {
    await _ensureReady();
    try {
      if (force || await isConnected) {
        await PrintBluetoothThermal.disconnect;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: nextMac);
      if (!ok) {
        // One more attempt after a short pause — common for PT265 on Android.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final retry = await PrintBluetoothThermal.connect(macPrinterAddress: nextMac);
        if (!retry) {
          throw PrinterException(
            'Could not connect to ${nextName.isEmpty ? 'the printer' : nextName}. '
            'Turn it on, keep it near the tablet, and make sure it is paired in Bluetooth settings.',
          );
        }
      }
      await Future<void>.delayed(Duration(milliseconds: _isAndroid ? 450 : 150));
      await remember(nextMac, nextName);
    } on PlatformException catch (error) {
      if (_isPermissionError(error)) {
        throw PrinterException(
          'Allow Nearby devices / Bluetooth for JA Merchandise, then try again.',
        );
      }
      throw PrinterException(
        'Could not connect to ${nextName.isEmpty ? 'the printer' : nextName}. ${error.message ?? ''}'.trim(),
      );
    }
  }

  Future<void> _ensureReady() async {
    if (_isAndroid) {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      final denied = statuses.values.any(
        (status) => status.isDenied || status.isPermanentlyDenied || status.isRestricted,
      );
      if (denied) {
        throw PrinterException(
          'Allow Nearby devices / Bluetooth for JA Merchandise in Android settings, then try again.',
        );
      }
    } else if (_needsRuntimeBluetoothPermission) {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!granted) {
        throw PrinterException(
          'Allow Nearby devices / Bluetooth for JA Merchandise, then try again.',
        );
      }
    }

    if (_needsRuntimeBluetoothPermission && !await PrintBluetoothThermal.bluetoothEnabled) {
      throw PrinterException('Turn on Bluetooth, then try again.');
    }
  }

  bool get _needsRuntimeBluetoothPermission =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool _isPermissionError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('permission') || message.contains('permission');
  }

  BluetoothInfo? _pickGoojprt(List<BluetoothInfo> devices) {
    BluetoothInfo? best;
    var bestScore = 0;
    for (final device in devices) {
      final next = _score(device.name);
      if (next > bestScore) {
        bestScore = next;
        best = device;
      }
    }
    if (bestScore > 0) return best;
    if (devices.length == 1) return devices.first;
    return null;
  }

  int _score(String raw) {
    final name = raw.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
    if (name.contains('goojprt')) return 100;
    if (RegExp(r'pt\d{2,}').hasMatch(name)) return 95;
    // XPrinter / XP-58H style 58mm ESC/POS printers
    if (name.contains('xprinter') || RegExp(r'^xp\d').hasMatch(name) || name.contains('xp58')) {
      return 94;
    }
    if (name.contains('mtp')) return 90;
    if (name.contains('pos58') || name.contains('pos80')) return 80;
    if (name.contains('jp58')) return 80;
    if (name.contains('thermal')) return 50;
    if (name.contains('printer')) return 40;
    return 0;
  }
}
