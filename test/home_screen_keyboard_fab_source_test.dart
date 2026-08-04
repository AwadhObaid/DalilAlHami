import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'HomeScreen keeps the keyboard visibility guard for the business FAB',
    () {
      final source = File(
        'lib/features/home/home_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'MediaQuery.viewInsetsOf(context).bottom > 0',
        ),
      );
      expect(
        source,
        contains(
          'floatingActionButton: isKeyboardVisible',
        ),
      );
    },
  );
}
