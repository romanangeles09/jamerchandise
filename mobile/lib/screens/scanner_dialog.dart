import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';

class ScanResult {
  const ScanResult({required this.code, required this.added, this.message = ''});

  final String code;
  final bool added;
  final String message;
}

Future<void> openBarcodeScanner({
  required BuildContext context,
  required Future<ScanResult> Function(String code) onScan,
  required List<CartItem> Function() cartItems,
  required double Function(CartItem item) unitPrice,
  required void Function(String id, int delta) onAdjustQty,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: JaColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _ScannerBody(
          onScan: onScan,
          cartItems: cartItems,
          unitPrice: unitPrice,
          onAdjustQty: onAdjustQty,
        ),
      );
    },
  );
}

class _ScannerBody extends StatefulWidget {
  const _ScannerBody({
    required this.onScan,
    required this.cartItems,
    required this.unitPrice,
    required this.onAdjustQty,
  });

  final Future<ScanResult> Function(String code) onScan;
  final List<CartItem> Function() cartItems;
  final double Function(CartItem item) unitPrice;
  final void Function(String id, int delta) onAdjustQty;

  @override
  State<_ScannerBody> createState() => _ScannerBodyState();
}

class _ScannerBodyState extends State<_ScannerBody> {
  final manual = TextEditingController();
  final focus = FocusNode();
  String lastCode = '';
  DateTime lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String error = '';
  String scanBuffer = '';
  DateTime lastScanKey = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    manual.dispose();
    focus.dispose();
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (focus.hasFocus) return false;

    final now = DateTime.now();
    if (now.difference(lastScanKey).inMilliseconds > 400) {
      scanBuffer = '';
    }
    lastScanKey = now;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = scanBuffer.trim();
      scanBuffer = '';
      if (code.isEmpty) return false;
      applyCode(code);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (scanBuffer.isEmpty) return false;
      scanBuffer = scanBuffer.substring(0, scanBuffer.length - 1);
      return true;
    }

    final char = _keyChar(event);
    if (char == null) return false;
    scanBuffer += char;
    return true;
  }

  String? _keyChar(KeyEvent event) {
    final character = event.character;
    if (character != null && character.isNotEmpty && character != '\n' && character != '\r') {
      return character;
    }
    final label = event.logicalKey.keyLabel;
    if (label.length == 1) return label;
    return null;
  }

  void submitManual() {
    final value = manual.text.trim();
    if (value.isEmpty) return;
    applyCode(value);
    manual.clear();
    focus.requestFocus();
  }

  Future<void> applyCode(String code) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (code == lastCode && now.difference(lastAt).inMilliseconds < 1600) return;
    lastCode = code;
    lastAt = now;
    final result = await widget.onScan(code);
    if (!mounted) return;
    setState(() {
      error = result.added ? '' : (result.message.isEmpty ? 'No product found for $code.' : result.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 420, maxHeight: size.height * 0.82),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Scan barcode', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Text(
              'Scan with the USB barcode scanner, or type a barcode or SKU. Items appear below.',
              style: TextStyle(color: JaColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (lastCode.isNotEmpty)
              Text('Last read: $lastCode', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (error.isNotEmpty) ...[const SizedBox(height: 8), JaAlert(error)],
            const SizedBox(height: 12),
            _cartList(),
            FieldLabel(
              label: 'Barcode or SKU',
              child: TextField(
                controller: manual,
                focusNode: focus,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(),
                onSubmitted: (_) => submitManual(),
              ),
            ),
            const SizedBox(height: 10),
            JaButton(label: 'Add', primary: true, expanded: true, onPressed: submitManual),
            const SizedBox(height: 8),
            JaButton(label: 'Done', expanded: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _cartList() {
    final items = widget.cartItems();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Scanned items will show here.', style: TextStyle(color: JaColors.muted, fontSize: 13)),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 240),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 12),
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${peso(widget.unitPrice(item))} / ${item.unit}',
                      style: const TextStyle(color: JaColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _qtyButton(Icons.remove, () {
                widget.onAdjustQty(item.product, -1);
                setState(() {});
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              _qtyButton(Icons.add, () {
                widget.onAdjustQty(item.product, 1);
                setState(() {});
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(backgroundColor: JaColors.cream),
      icon: Icon(icon, size: 16, color: JaColors.ink),
    );
  }
}
