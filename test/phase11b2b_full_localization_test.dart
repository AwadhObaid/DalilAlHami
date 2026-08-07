import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/localization/app_localized_text.dart'
    as localized;
import 'package:hami_guide/core/services/app_preferences_store.dart';
import 'package:hami_guide/features/profile/widgets/add_business_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesStore.instance.initialize(reload: true);
  });

  setUp(() async {
    await AppPreferencesStore.instance.setLocaleCode('ar');
  });

  tearDown(() async {
    await AppPreferencesStore.instance.setLocaleCode('ar');
  });

  test('Phase 11B2B translates representative remaining surfaces', () async {
    await AppPreferencesStore.instance.setLocaleCode('en');

    expect(localized.AppLocaleText.runtime('حسابي'), 'Account');
    expect(localized.AppLocaleText.runtime('أنشطتي'), 'My businesses');
    expect(
        localized.AppLocaleText.runtime('إضافة نشاط جديد'), 'Add new business');
    expect(localized.AppLocaleText.runtime('بيانات الحساب'), 'Account details');
    expect(localized.AppLocaleText.runtime('لوحة تحكم الإدارة'),
        'Admin dashboard');
    expect(localized.AppLocaleText.runtime('إدارة المستخدمين'), 'Manage users');
    expect(localized.AppLocaleText.runtime('إدارة الإعلانات'),
        'Manage advertisements');
    expect(localized.AppLocaleText.runtime('تحديد موقع النشاط'),
        'Set business location');
    expect(localized.AppLocaleText.runtime('3 نشاط'), '3 businesses');
    expect(
      localized.AppLocaleText.runtime('لديك 2 نشاط'),
      'You have 2 businesses',
    );
    expect(
      localized.AppLocaleText.runtime('5 نشاط • 3 معتمد • 2 بانتظار المراجعة'),
      '5 businesses • 3 approved • 2 awaiting review',
    );
  });

  testWidgets('Add business action follows the stored English preference', (
    tester,
  ) async {
    await AppPreferencesStore.instance.setLocaleCode('en');

    await tester.pumpWidget(
      material.MaterialApp(
        locale: const material.Locale('en'),
        home: material.Scaffold(
          body: AddBusinessButton(onPressed: () {}),
        ),
      ),
    );

    expect(find.text('Add new business'), findsOneWidget);
    expect(find.text('إضافة نشاط جديد'), findsNothing);
  });

  test('Phase 11B2B source contract covers account/admin UI files', () {
    final manifest = File('PHASE_11B2B_LOCALIZED_SURFACES.txt');
    expect(manifest.existsSync(), isTrue);

    final surfaces = manifest
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    expect(surfaces.length, greaterThanOrEqualTo(20));

    final directPresentationString = RegExp(
      r'''(?:tooltip|labelText|hintText|helperText|semanticLabel)\s*:\s*['"][^'"]*[\u0600-\u06FF]''',
    );

    for (final relative in surfaces) {
      expect(relative.startsWith('lib/'), isTrue, reason: relative);
      final file = File(relative);
      expect(file.existsSync(), isTrue, reason: relative);
      final source = file.readAsStringSync();
      expect(source, contains('hide Text'), reason: relative);
      expect(source, contains('app_localized_text.dart'), reason: relative);
      expect(
        directPresentationString.hasMatch(source),
        isFalse,
        reason: 'Raw non-Text localized property remains in $relative',
      );
    }

    final localization = File(
      'lib/core/localization/app_localized_text.dart',
    ).readAsStringSync();
    expect(localization, contains('static String runtime(String value)'));
    expect(localization, contains('Phase 11B2B account'));
    expect(localization, contains("'حسابي': 'Account'"));
    expect(localization, contains("'إدارة المستخدمين': 'Manage users'"));
    expect(localization, contains("'لوحة تحكم الإدارة': 'Admin dashboard'"));
  });
}
