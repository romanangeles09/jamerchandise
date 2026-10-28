import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_pos_mobile/theme.dart';

void main() {
  testWidgets('theme builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJaTheme(),
        home: const Scaffold(body: Text('JA Merchandise')),
      ),
    );
    expect(find.text('JA Merchandise'), findsOneWidget);
  });
}
