import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('اسم تطبيق Android يستخدم موردًا ثابتًا غير معرض لتلف الترميز', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(strings, contains('<string name="app_name">'));
    expect(strings, contains('&#x062F;&#x0644;&#x064A;&#x0644;'));
    expect(
        strings, contains('&#x0627;&#x0644;&#x062D;&#x0627;&#x0645;&#x064A;'));
    expect(strings, isNot(contains('ط§')));
    expect(strings, isNot(contains('ظ„')));
  });
}
