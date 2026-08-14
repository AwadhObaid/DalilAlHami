import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 17B.1 contact presentation is wired across public call surfaces',
      () {
    final model = File('lib/models/business.dart').readAsStringSync();
    final helper = File(
      'lib/features/shared/utils/business_contact_actions.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    final directoryCard = File(
      'lib/features/directory/widgets/business_card.dart',
    ).readAsStringSync();
    final homeCard = File(
      'lib/features/home/widgets/home_business_card.dart',
    ).readAsStringSync();

    expect(model, contains('effectiveContactNumbers'));
    expect(model, contains('whatsappContactNumber'));
    expect(model, contains('hasMultiplePhoneNumbers'));
    expect(helper, contains('showModalBottomSheet<BusinessContactNumber>'));
    expect(helper, contains('textDirection: TextDirection.ltr'));
    expect(details, contains('BusinessContactActions.call(context, business)'));
    expect(details, contains('..._buildContactNumberRows(context)'));
    expect(details, contains('valueTextDirection: TextDirection.ltr'));
    expect(
      directoryCard,
      contains('BusinessContactActions.call(context, business)'),
    );
    expect(
      homeCard,
      contains('BusinessContactActions.call(context, business)'),
    );
  });
}
