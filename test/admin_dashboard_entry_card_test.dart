import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/admin/widgets/admin_dashboard_entry_card.dart';

void main() {
  testWidgets('بطاقة الإدارة تعرض الهوية وتفتح اللوحة', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDashboardEntryCard(
            onTap: () {
              opened = true;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(AdminDashboardEntryCard.cardKey), findsOneWidget);
    expect(find.text('لوحة تحكم الإدارة'), findsOneWidget);

    await tester.tap(find.byKey(AdminDashboardEntryCard.cardKey));
    await tester.pump();

    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
