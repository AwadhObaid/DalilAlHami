import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 08B keeps Android DEX build memory within a stable contract', () {
    final propertiesFile = File('android/gradle.properties');
    expect(propertiesFile.existsSync(), isTrue);

    final source = propertiesFile.readAsStringSync();
    final heapMatch = RegExp(
      r'^org\.gradle\.jvmargs=.*-Xmx(\d+)m',
      multiLine: true,
    ).firstMatch(source);

    expect(heapMatch, isNotNull);
    expect(int.parse(heapMatch!.group(1)!), greaterThanOrEqualTo(4096));
    expect(source, contains('org.gradle.workers.max=1'));
    expect(source, contains('org.gradle.parallel=false'));
    expect(source, contains('org.gradle.daemon=false'));
    expect(source, contains('kotlin.compiler.execution.strategy=in-process'));
  });

  test('the adaptive memory configurator keeps recommended and emergency modes',
      () {
    final script = File(
      'scripts/configure_phase_08b_gradle_memory.ps1',
    ).readAsStringSync();

    expect(script, contains('[ValidateSet("Recommended", "Emergency")]'));
    expect(script, contains('Get-AdaptiveHeapMb'));
    expect(script, contains('org.gradle.jvmargs'));
    expect(script, contains('org.gradle.workers.max'));
    expect(script, contains('kotlin.compiler.execution.strategy'));
  });
}
