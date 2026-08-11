import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no legacy phone or OTP authentication page remains', () {
    expect(
      File('lib/features/auth/phone_entry_page.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/auth/otp_page.dart').existsSync(),
      isFalse,
    );
  });

  test('production Google authentication surface remains present', () {
    final accountHub =
        File('lib/features/profile/account_hub_page.dart').readAsStringSync();
    final googlePage =
        File('lib/features/auth/google_sign_in_page.dart').readAsStringSync();
    final googleService =
        File('lib/core/services/google_auth_service.dart').readAsStringSync();

    expect(accountHub, contains('GoogleSignInPage'));
    expect(accountHub, contains('المتابعة باستخدام Google'));
    expect(googleService, contains('signInWithOAuth'));
    expect(googlePage, isNotEmpty);
  });

  test('active source contains no references to legacy OTP page', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      if (source.contains('OtpPage') || source.contains('otp_page.dart')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
