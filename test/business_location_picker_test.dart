import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/location/business_location.dart';
import 'package:hami_guide/features/shared/widgets/business_location_picker.dart';

void main() {
  testWidgets('يحدد الموقع من الصفحة ويستطيع إزالته', (tester) async {
    BusinessLocation? selected;
    const picked = BusinessLocation(
      latitude: 14.81,
      longitude: 49.83,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BusinessLocationPicker(
                location: selected,
                pageOpener: (_, __) async => picked,
                onChanged: (value) {
                  setState(() => selected = value);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('business-location-map-action')),
    );
    await tester.pump();

    expect(selected, picked);
    expect(
      find.byKey(
        const ValueKey<String>('business-location-coordinates'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('business-location-clear-action')),
    );
    await tester.pump();

    expect(selected, isNull);
    expect(find.text('لم يتم تحديد موقع جغرافي.'), findsOneWidget);
  });
}
