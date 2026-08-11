import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy demo phone authentication surface is removed', () {
    expect(
      File('lib/features/auth/phone_entry_page.dart').existsSync(),
      isFalse,
    );

    final localization = File('lib/core/localization/app_localized_text.dart')
        .readAsStringSync();

    expect(
      localization,
      isNot(contains('هذه شاشة تحقق تجريبية حاليًا')),
    );
    expect(
      localization,
      isNot(contains('تمت إعادة إرسال الرمز التجريبي.')),
    );
    expect(
      localization,
      isNot(contains("'إرسال رمز التحقق':")),
    );
  });

  test('production authentication remains Google through Supabase', () {
    final accountHub =
        File('lib/features/profile/account_hub_page.dart').readAsStringSync();
    final googlePage =
        File('lib/features/auth/google_sign_in_page.dart').readAsStringSync();

    expect(accountHub, contains('GoogleSignInPage'));
    expect(accountHub, contains('المتابعة باستخدام Google'));
    expect(
      googlePage,
      anyOf(
        contains('GoogleAuthService'),
        contains('signInWithGoogle'),
        contains('Supabase'),
      ),
    );
  });

  test('no Dart source references PhoneEntryPage', () {
    final roots = <Directory>[
      Directory('lib'),
      Directory('test'),
    ];

    final offending = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) {
        continue;
      }

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path.endsWith(
          'phase15a_authentication_cleanup_contract_test.dart',
        )) {
          continue;
        }

        final source = entity.readAsStringSync();
        if (source.contains('PhoneEntryPage') ||
            source.contains('phone_entry_page.dart')) {
          offending.add(entity.path);
        }
      }
    }

    expect(offending, isEmpty);
  });
}
