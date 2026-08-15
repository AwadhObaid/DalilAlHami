import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/features/shared/widgets/business_contact_editor.dart';
import 'package:hami_guide/models/business_contact_draft.dart';

void main() {
  testWidgets(
      'editor adds contacts, keeps digits LTR, and enforces one WhatsApp', (
    tester,
  ) async {
    List<BusinessContactDraft> latest = const <BusinessContactDraft>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusinessContactEditor(
              initialValue: <BusinessContactDraft>[
                BusinessContactDraft.emptyPrimary(),
              ],
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('business-contact-add-number')));
    await tester.pump();
    expect(
        find.byKey(const ValueKey('business-contact-row-1')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('business-contact-phone-0')),
      '05340080',
    );
    await tester.enterText(
      find.byKey(const ValueKey('business-contact-phone-1')),
      '773272911',
    );

    var whatsapp = find.byKey(const ValueKey('business-contact-whatsapp-0'));
    await tester.ensureVisible(whatsapp);
    await tester.tap(whatsapp);
    await tester.pump();

    whatsapp = find.byKey(const ValueKey('business-contact-whatsapp-1'));
    await tester.ensureVisible(whatsapp);
    await tester.tap(whatsapp);
    await tester.pump();

    expect(latest, hasLength(2));
    expect(latest.first.isPrimary, isTrue);
    expect(latest.first.supportsWhatsApp, isFalse);
    expect(latest.last.supportsWhatsApp, isTrue);

    final phoneFormField =
        find.byKey(const ValueKey('business-contact-phone-0'));
    final innerTextField = find.descendant(
      of: phoneFormField,
      matching: find.byType(TextField),
    );
    expect(innerTextField, findsOneWidget);

    final phoneField = tester.widget<TextField>(innerTextField);
    expect(phoneField.textDirection, TextDirection.ltr);
    expect(phoneField.textAlign, TextAlign.left);
  });
}
