import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  required ScanResult Function(String code) onScan,
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

  final ScanResult Function(String code) onScan;
  final List<CartItem> Function() cartItems;
  final double Function(CartItem item) unitPrice;
  final void Function(String id, int delta) onAdjustQty;

  @override
  State<_ScannerBody> createState() => _ScannerBodyState();
}

class _ScannerBodyState extends State<_ScannerBody> {
  final manual = TextEditingController();
  late final MobileScannerController controller;
  StreamSubscription<Object>? subscription;
  String lastCode = '';
  DateTime lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String error = '';
  bool torchOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.unrestricted,
      cameraResolution: const Size(1920, 1080),
    );
    subscription = controller.barcodes.listen(_onCapture, onError: (_) {});
  }

  @override
  void dispose() {
    subscription?.cancel();
    manual.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
      if (value.isNotEmpty) {
        applyCode(value);
        return;
      }
    }
  }

  void applyCode(String code) {
    if (!mounted) return;
    final now = DateTime.now();
    if (code == lastCode && now.difference(lastAt).inMilliseconds < 1600) return;
    lastCode = code;
    lastAt = now;
    final result = widget.onScan(code);
    setState(() {
      error = result.added ? '' : (result.message.isEmpty ? 'No product found for $code.' : result.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      width: size.width * 0.86,
      height: size.height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Scan barcode', style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                        onPressed: () async {
                          await controller.toggleTorch();
                          if (mounted) setState(() => torchOn = !torchOn);
                        },
                        icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off_outlined),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: JaColors.ink,
                        child: MobileScanner(
                          controller: controller,
                          fit: BoxFit.contain,
                          onDetect: _onCapture,
                          errorBuilder: (context, error) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Camera could not start. Type the barcode on the right.',
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Hold the barcode inside the camera. The last read value appears below.',
                    style: TextStyle(color: JaColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (lastCode.isNotEmpty)
                    Text('Last read: $lastCode', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (error.isNotEmpty) ...[const SizedBox(height: 8), JaAlert(error)],
                  const SizedBox(height: 12),
                  Expanded(child: _cartList()),
                  FieldLabel(
                    label: 'Barcode or SKU',
                    child: TextField(
                      controller: manual,
                      decoration: const InputDecoration(),
                      onSubmitted: (value) {
                        if (value.trim().isEmpty) return;
                        applyCode(value.trim());
                        manual.clear();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  JaButton(
                    label: 'Add',
                    primary: true,
                    expanded: true,
                    onPressed: () {
                      final value = manual.text.trim();
                      if (value.isEmpty) return;
                      applyCode(value);
                      manual.clear();
                    },
                  ),
                  const SizedBox(height: 8),
                  JaButton(label: 'Done', expanded: true, onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartList() {
    final items = widget.cartItems();
    if (items.isEmpty) {
      return const Text('Scanned items will show here.', style: TextStyle(color: JaColors.muted, fontSize: 13));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
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
