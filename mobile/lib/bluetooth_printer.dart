import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
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
    await _connectTo(printer.mac, printer.name);
  }

  Future<void> printBytes(List<int> bytes) async {
    if (!isSupported) {
      throw PrinterException('Bluetooth printing is only available in the tablet app.');
    }
    await ensureConnected();
    var ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      await PrintBluetoothThermal.disconnect;
      await ensureConnected();
      ok = await PrintBluetoothThermal.writeBytes(bytes);
    }
    if (!ok) {
      throw PrinterException('Printer did not accept the job. Check paper and power, then try again.');
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

  Future<void> ensureConnected() async {
    if (!isSupported) {
      throw PrinterException('Bluetooth printing is only available in the tablet app.');
    }
    await loadSaved();
    if (await isConnected && mac.isNotEmpty) return;

    await _ensureReady();
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
      throw PrinterException(
        'No GOOJPRT printer found among paired Bluetooth devices. Pair it in system Bluetooth settings, then print again.',
      );
    }
    await _connectTo(target.macAdress, target.name);
  }

  Future<void> _connectTo(String nextMac, String nextName) async {
    if (await isConnected) {
      await PrintBluetoothThermal.disconnect;
    }
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: nextMac);
    if (!ok) {
      throw PrinterException(
        'Could not connect to ${nextName.isEmpty ? 'the printer' : nextName}. Turn it on, keep it in range, then try again.',
      );
    }
    await remember(nextMac, nextName);
  }

  Future<void> _ensureReady() async {
    if (!_skipsBluetoothToggle && !await _bluetoothOn()) {
      throw PrinterException('Turn on Bluetooth, then try again.');
    }
    if (!_skipsBluetoothToggle && !await _permissionGranted()) {
      throw PrinterException('Allow Bluetooth so JA POS can print to the GOOJPRT printer.');
    }
  }

  bool get _skipsBluetoothToggle => defaultTargetPlatform == TargetPlatform.windows;

  Future<bool> _bluetoothOn() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _permissionGranted() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return true;
    }
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
    final name = raw.toLowerCase();
    if (name.contains('goojprt')) return 100;
    if (name.contains('mtp')) return 90;
    if (name.contains('pt-210') || name.contains('pt210')) return 90;
    if (name.contains('pos58') || name.contains('pos80') || name.contains('pos-58')) return 80;
    if (name.contains('jp-58') || name.contains('jp58')) return 80;
    if (name.contains('thermal')) return 50;
    if (name.contains('printer')) return 40;
    return 0;
  }
}
