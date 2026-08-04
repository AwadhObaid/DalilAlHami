import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/profile/widgets/empty_owned_business_state.dart';

void main() {
  testWidgets(
    'حالة عدم وجود نشاط تعرض زر إضافة نشاط جديد وتنفذ الإجراء',
    (WidgetTester tester) async {
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyOwnedBusinessState(
              onAddPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('لا يوجد نشاط مسجل في حسابك'), findsOneWidget);
      expect(
        find.byKey(EmptyOwnedBusinessState.addButtonKey),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(EmptyOwnedBusinessState.addButtonKey),
      );
      await tester.pump();

      expect(wasPressed, isTrue);
    },
  );
}
