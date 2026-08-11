import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 14C contact administration source contract', () {
    final constants = File(
      'lib/core/constants/app_contact_constants.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/profile/contact_admin_page.dart',
    ).readAsStringSync();
    final hub = File(
      'lib/features/profile/account_hub_page.dart',
    ).readAsStringSync();

    expect(constants, contains("adminWhatsAppNumber = '967772551846'"));

    for (final token in <String>[
      'ContactAdminCategory.inquiry',
      'ContactAdminCategory.suggestion',
      'ContactAdminCategory.report',
      'ContactAdminCategory.technicalIssue',
      'ContactAdminCategory.businessDataChange',
      'PackageInfo.fromPlatform()',
      'LaunchActions.openWhatsApp(',
      'AppContactConstants.adminWhatsAppNumber',
      'نوع الطلب:',
      'الاسم:',
      'رقم الهاتف:',
      'إصدار التطبيق:',
      'contact-admin-whatsapp-button',
    ]) {
      expect(page, contains(token), reason: token);
    }

    expect(hub, contains("import 'contact_admin_page.dart';"));
    expect(hub, contains('ContactAdminPage()'));
    expect(hub, contains("'التواصل مع الإدارة'"));
    expect(hub, contains('AppColors.whatsapp'));

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    final numberFiles = dartFiles
        .where((file) => file.readAsStringSync().contains('967772551846'))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toList(growable: false);

    expect(
      numberFiles,
      <String>['lib/core/constants/app_contact_constants.dart'],
      reason: 'Official admin WhatsApp number must have one source of truth.',
    );
  });
}
