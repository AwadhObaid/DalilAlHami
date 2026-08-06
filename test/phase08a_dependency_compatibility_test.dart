import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('اعتمادات الصور والإشعارات مثبتة على نطاق متوافق', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains('image: 4.8.0'),
      reason: 'يجب تثبيت image 4.8.0 دون ^ لمنع اختيار 4.9.x تلقائيًا.',
    );
    expect(pubspec, isNot(contains('image: ^4.8.0')));
    expect(pubspec, isNot(contains('image: ^4.9.1')));
    expect(pubspec, contains('flutter_local_notifications: ^19.5.0'));
  });
}
