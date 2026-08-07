import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 11A Google auth messages are valid Arabic UTF-8 text', () {
    final source = File(
      'lib/core/services/google_auth_service.dart',
    ).readAsStringSync();

    for (final expected in <String>[
      'إعداد Supabase غير متاح في هذا التشغيل.',
      'تعذر فتح تسجيل Google. تحقق من الإنترنت وحاول مرة أخرى.',
      'تسجيل Google غير مفعّل في إعدادات Supabase.',
      'رابط الرجوع من Google غير مضبوط في Supabase.',
      'تعذر الاتصال بخدمة تسجيل الدخول.',
    ]) {
      expect(source, contains(expected), reason: expected);
    }

    for (final mojibake in <String>[
      'ط¥',
      'ط؛',
      'ظ…',
      'ظ„',
      'ط±',
    ]) {
      expect(source, isNot(contains(mojibake)), reason: mojibake);
    }
  });
}
