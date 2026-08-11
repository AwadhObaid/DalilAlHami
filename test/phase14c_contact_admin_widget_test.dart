import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/features/profile/contact_admin_page.dart';

void main() {
  testWidgets('contact administration composes structured WhatsApp message',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? launchedPhone;
    String? launchedMessage;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContactAdminPage(
          initialName: 'عوض',
          initialPhone: '777111222',
          versionLoader: () async => '1.0.7+9',
          launcher: (
            context,
            phoneNumber, {
            message,
          }) async {
            launchedPhone = phoneNumber;
            launchedMessage = message;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('التواصل مع الإدارة'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('contact-admin-category-field')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('contact-admin-category-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشكلة تقنية').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('contact-admin-message-field')),
      'هناك مشكلة في فتح تفاصيل النشاط.',
    );

    final button =
        find.byKey(const ValueKey<String>('contact-admin-whatsapp-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(launchedPhone, '967772551846');
    expect(launchedMessage, isNotNull);
    expect(launchedMessage, contains('نوع الطلب: مشكلة تقنية'));
    expect(launchedMessage, contains('الاسم: عوض'));
    expect(launchedMessage, contains('رقم الهاتف: 777111222'));
    expect(launchedMessage, contains('إصدار التطبيق: 1.0.7+9'));
    expect(
      launchedMessage,
      contains('هناك مشكلة في فتح تفاصيل النشاط.'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact administration validates required details',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var launched = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContactAdminPage(
          initialName: '',
          initialPhone: '',
          versionLoader: () async => '1.0.7+9',
          launcher: (
            context,
            phoneNumber, {
            message,
          }) async {
            launched = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button =
        find.byKey(const ValueKey<String>('contact-admin-whatsapp-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(launched, isFalse);
    expect(find.text('أدخل الاسم.'), findsOneWidget);
    expect(find.text('أدخل رقم هاتف صحيحًا.'), findsOneWidget);
    expect(find.text('اكتب تفاصيل الطلب.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
