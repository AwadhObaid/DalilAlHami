import 'dart:io';

import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/localization/app_localized_text.dart'
    as localized;
import 'package:hami_guide/core/services/app_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferencesStore.instance.initialize(reload: true);
  });

  setUp(() async {
    await AppPreferencesStore.instance.setLocaleCode('ar');
  });

  testWidgets('localized Text renders English and Material direction is LTR', (
    tester,
  ) async {
    await AppPreferencesStore.instance.setLocaleCode('en');
    await tester.pumpWidget(
      const material.MaterialApp(
        locale: material.Locale('en'),
        supportedLocales: <material.Locale>[
          material.Locale('ar'),
          material.Locale('en'),
        ],
        localizationsDelegates: <material.LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: material.Scaffold(
          body: localized.Text('إعدادات التطبيق'),
        ),
      ),
    );

    expect(find.text('App settings'), findsOneWidget);
    final context = tester.element(find.byType(material.Scaffold));
    expect(material.Directionality.of(context), material.TextDirection.ltr);
  });

  testWidgets(
    'implicit MaterialApp locale does not override the stored Arabic preference',
    (tester) async {
      await tester.pumpWidget(
        const material.MaterialApp(
          home: material.Scaffold(
            body: localized.Text('إعدادات التطبيق'),
          ),
        ),
      );

      expect(find.text('إعدادات التطبيق'), findsOneWidget);
      expect(find.text('App settings'), findsNothing);
    },
  );

  testWidgets('Arabic locale preserves Arabic text and RTL direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      const material.MaterialApp(
        locale: material.Locale('ar'),
        supportedLocales: <material.Locale>[
          material.Locale('ar'),
          material.Locale('en'),
        ],
        localizationsDelegates: <material.LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: material.Scaffold(
          body: localized.Text('إعدادات التطبيق'),
        ),
      ),
    );

    expect(find.text('إعدادات التطبيق'), findsOneWidget);
    final context = tester.element(find.byType(material.Scaffold));
    expect(material.Directionality.of(context), material.TextDirection.rtl);
  });

  test('Phase 11B2A source contract activates persisted English safely', () {
    final preferences = File(
      'lib/core/services/app_preferences_store.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/app_settings_page.dart',
    ).readAsStringSync();
    final app = File('lib/app/hami_guide_app.dart').readAsStringSync();
    final localization = File(
      'lib/core/localization/app_localized_text.dart',
    ).readAsStringSync();

    expect(preferences, contains("rawLocale == 'en' ? 'en' : 'ar'"));
    final snapshotUpdate = preferences.indexOf(
      '_snapshot = _snapshot.copyWith(localeCode: normalized);',
    );
    final persistence = preferences.indexOf(
      'await _preferences!.setString(localeKey, normalized);',
    );
    expect(snapshotUpdate, greaterThanOrEqualTo(0));
    expect(persistence, greaterThan(snapshotUpdate));

    expect(settings, contains('settings-language-ar'));
    expect(settings, contains('settings-language-en'));
    expect(settings, isNot(contains('settings-language-en-coming')));
    expect(app, contains("Locale(snapshot.localeCode)"));
    expect(app, contains("Locale('ar')"));
    expect(app, contains("Locale('en')"));
    expect(
        localization, contains('class Text extends material.StatelessWidget'));
    expect(localization, contains('preferences.isInitialized'));
    expect(localization, contains("preferences.snapshot.localeCode == 'en'"));
    expect(
        localization, isNot(contains('Localizations.maybeLocaleOf(context)')));
    expect(localization, contains("'إعدادات التطبيق': 'App settings'"));
    expect(localization, contains("'صيدليات': 'Pharmacies'"));
  });
}
