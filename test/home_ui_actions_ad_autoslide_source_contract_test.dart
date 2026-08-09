import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header separates settings, search, and filters', () {
    final header = File(
      'lib/features/home/widgets/home_header.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/home/home_dashboard_page.dart',
    ).readAsStringSync();

    expect(header, contains('this.onOpenSettings'));
    expect(header, contains('final VoidCallback? onOpenSettings;'));
    expect(header, isNot(contains('required this.onOpenSettings')));
    expect(header, contains('icon: Icons.settings_rounded'));
    expect(header, contains('onPressed: onOpenSettings'));
    expect(header, contains("key: const ValueKey<String>('home-filter-button')"));
    expect(header, contains('onTap: onOpenFilters'));

    expect(dashboard, contains('onOpenSettings: _openSettings'));
    expect(dashboard, contains('onOpenFilters: widget.onOpenSearch'));
    expect(dashboard, contains('builder: (context) => const AppSettingsPage()'));
  });

  test('home no longer injects transport services shortcut', () {
    final dashboard = File(
      'lib/features/home/home_dashboard_page.dart',
    ).readAsStringSync();

    expect(dashboard, isNot(contains('_transportHub')));
    expect(dashboard, isNot(contains("name: 'خدمات النقل'")));
    expect(dashboard, contains('final result = <ServiceCategory>[];'));
  });

  test('advertisement slider auto-advances and loops safely', () {
    final slider = File(
      'lib/features/home/widgets/ad_slider.dart',
    ).readAsStringSync();

    expect(slider, contains("import 'dart:async';"));
    expect(slider, contains('Duration(seconds: 4)'));
    expect(slider, contains('Duration(milliseconds: 550)'));
    expect(slider, contains('widget.controller.nextPage('));
    expect(slider, contains('widget.advertisements.length + 1'));
    expect(slider, contains('widget.controller.jumpToPage(0)'));
    expect(slider, contains('onPointerDown: (_) => _pauseForInteraction()'));
    expect(slider, contains('onPointerUp: (_) => _resumeAfterInteraction()'));
    expect(slider, contains('widget.advertisements.length <= 1'));
  });
}
