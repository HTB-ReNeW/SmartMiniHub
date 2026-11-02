import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/screens/operations/unit_price_screen.dart';

void main() {
  testWidgets('UnitPriceScreen builds without crash and opens create dialog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnitPriceScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Cấu hình loại kho'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap on '+ Thêm loại kho' action button
    final addButtons = find.text('Thêm loại kho');
    expect(addButtons, findsWidgets);

    await tester.tap(addButtons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dialog opened without error
    expect(find.text('Tạo loại kho mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
