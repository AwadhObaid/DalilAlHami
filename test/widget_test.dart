import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/home/home_screen.dart';
import 'package:hami_guide/main.dart';

void main() {
  testWidgets(
    'يفتح التطبيق وينتقل من شاشة البداية إلى الرئيسية',
    (WidgetTester tester) async {
      await tester.pumpWidget(const HamiGuideApp());

      expect(find.text('أهلاً بك في التطبيق'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.text('ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…'),
        findsOneWidget,
      );
    },
  );
}
