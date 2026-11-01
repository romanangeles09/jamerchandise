import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

const _patterns = [
  '11011001100', '11001101100', '11001100110', '10010011000', '10010001100',
  '10001001100', '10011001000', '10011000100', '10001100100', '11001001000',
  '11001000100', '11000100100', '10110011100', '10011011100', '10011001110',
  '10111001100', '10011101100', '10011100110', '11001110010', '11001011100',
  '11001001110', '11011100100', '11001110100', '11101101110', '11101001100',
  '11100101100', '11100100110', '11101100100', '11100110100', '11100110010',
  '11011011000', '11011000110', '11000110110', '10100011000', '10001011000',
  '10001000110', '10110001000', '10001101000', '10001100010', '11010001000',
  '11000101000', '11000100010', '10110111000', '10110001110', '10001101110',
  '10111011000', '10111000110', '10001110110', '11101110110', '11010001110',
  '11000101110', '11011101000', '11011100010', '11011101110', '11101011000',
  '11101000110', '11100010110', '11101101000', '11101100010', '11100011010',
  '11101111010', '11001000010', '11110001010', '10100110000', '10100001100',
  '10010110000', '10010000110', '10000101100', '10000100110', '10110010000',
  '10110000100', '10011010000', '10011000010', '10000110100', '10000110010',
  '11000010010', '11001010000', '11110111010', '11000010100', '10001111010',
  '10100111100', '10010111100', '10010011110', '10111100100', '10011110100',
  '10011110010', '11110100100', '11110010100', '11110010010', '11011011110',
  '11011110110', '11110110110', '10101111000', '10100011110', '10001011110',
  '10111101000', '10111100010', '11110101000', '11110100010', '10111011110',
  '10111101110', '11101011110', '11110101110', '11010000100', '11010010000',
  '11010011100', '11000111010',
];

String generateCode128Value() {
  final rand = Random.secure();
  return '${rand.nextInt(9) + 1}${List.generate(12, (_) => rand.nextInt(10)).join()}';
}

String nextCode128Barcode(Iterable<String> used) {
  final taken = used.toSet();
  for (var attempt = 0; attempt < 40; attempt += 1) {
    final code = generateCode128Value();
    if (!taken.contains(code)) return code;
  }
  return DateTime.now().millisecondsSinceEpoch.toString().padLeft(13, '0').substring(0, 13);
}

String code128Bits(String value) {
  if (value.isEmpty) return '';
  const start = 104;
  final codes = <int>[start];
  var checksum = start;
  for (var i = 0; i < value.length; i += 1) {
    final code = value.codeUnitAt(i) - 32;
    if (code < 0 || code > 94) return '';
    codes.add(code);
    checksum += code * (i + 1);
  }
  codes.add(checksum % 103);
  codes.add(106);
  return '${codes.map((code) => _patterns[code]).join()}11';
}

class Code128Graphic extends StatelessWidget {
  const Code128Graphic({super.key, required this.value, this.height = 88});

  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: JaColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: value.isEmpty
            ? SizedBox(
                height: height,
                child: const Center(child: Text('Auto', style: TextStyle(color: JaColors.muted))),
              )
            : CustomPaint(
                painter: _Code128Painter(value),
                child: SizedBox(width: double.infinity, height: height),
              ),
      ),
    );
  }
}

class _Code128Painter extends CustomPainter {
  _Code128Painter(this.value);

  final String value;

  @override
  void paint(Canvas canvas, Size size) {
    final bits = code128Bits(value);
    if (bits.isEmpty) return;
    const labelHeight = 18.0;
    final barHeight = size.height - labelHeight;
    final module = size.width / bits.length;
    final paint = Paint()..color = JaColors.ink;
    var x = 0.0;
    for (var i = 0; i < bits.length; i += 1) {
      if (bits[i] == '1') {
        canvas.drawRect(Rect.fromLTWH(x, 0, module, barHeight), paint);
      }
      x += module;
    }
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(color: JaColors.ink, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    text.paint(canvas, Offset((size.width - text.width) / 2, barHeight + 1));
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant _Code128Painter oldDelegate) => oldDelegate.value != value;
}
