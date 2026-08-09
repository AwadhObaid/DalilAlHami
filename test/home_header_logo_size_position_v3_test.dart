import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header official logo uses final enlarged and raised values', () {
    final source =
        File('lib/features/home/widgets/home_header.dart').readAsStringSync();

    expect(source, contains("'home-brand-logo'"));
    expect(source, contains('width: 260'));
    expect(source, contains('height: 124'));
    expect(source, contains('Offset(0, -23)'));
    expect(source, contains('alignment: Alignment.center'));
    expect(source, contains("'assets/home_header_logo.png'"));
  });
}
