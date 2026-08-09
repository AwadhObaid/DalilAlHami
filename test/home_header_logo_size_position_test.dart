import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header official logo remains centered and safely positioned', () {
    final source =
        File('lib/features/home/widgets/home_header.dart').readAsStringSync();

    expect(source, contains("'home-brand-logo'"));
    expect(source, contains("'assets/home_header_logo.png'"));
    expect(source, contains('Transform.translate('));
    expect(source, contains('SizedBox('));
    expect(source, contains('fit: BoxFit.contain'));
    expect(source, contains('alignment: Alignment.center'));
  });
}
