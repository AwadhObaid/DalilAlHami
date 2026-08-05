import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/theme/app_theme.dart';
import 'package:hami_guide/data/directory_data_store.dart';

void preparePhase06bData() {
  DirectoryDataStore.instance.prepareBundledDataForTesting();
}

Future<void> pumpPhase06bPage(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(360, 800),
  double textScale = 1,
  double keyboardInset = 0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) {
      debugPrint('PHASE 06B RESPONSIVE LAYOUT FAILURE');
      debugPrint(details.toString());
    }

    previousErrorHandler?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = previousErrorHandler;
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        );
      },
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapPhase06bControl(
  WidgetTester tester,
  Finder finder,
) async {
  expect(
    finder,
    findsOneWidget,
    reason: 'عنصر التحكم المطلوب غير موجود في شجرة الواجهة.',
  );

  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void expectNoPhase06bException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }

  final overflowDiagnostics = tester.allRenderObjects
      .whereType<RenderFlex>()
      .where(
        (renderFlex) => renderFlex.toStringShort().contains('OVERFLOWING'),
      )
      .map((renderFlex) => renderFlex.toStringDeep())
      .join('\n--- OVERFLOWING FLEX ---\n');

  expect(
    exception,
    isNull,
    reason: overflowDiagnostics.isEmpty
        ? 'لم يُحدَّد RenderFlex المتجاوز داخل شجرة العرض.'
        : overflowDiagnostics,
  );
}
