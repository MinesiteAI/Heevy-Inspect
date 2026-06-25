import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heevy_inspect/config/heevy_brand.dart';

void main() {
  testWidgets('Heevy Inspect brand smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text(HeevyBrand.appTitle)),
      ),
    );
    expect(find.text('Heevy Inspect'), findsOneWidget);
  });
}
