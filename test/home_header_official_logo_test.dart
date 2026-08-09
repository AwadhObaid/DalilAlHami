import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header uses the official supplied logo asset', () {
    final header =
        File('lib/features/home/widgets/home_header.dart').readAsStringSync();
    final logo = File('assets/home_header_logo.png');

    expect(logo.existsSync(), isTrue);
    expect(logo.lengthSync(), greaterThan(1000));

    expect(header, contains("'home-brand-logo'"));
    expect(header, contains("'assets/home_header_logo.png'"));
    expect(header, contains('Image.asset('));
    expect(
      header,
      isNot(contains("Icons.location_on_rounded,\n"
          "                                      color: AppColors.white")),
    );
  });
}
