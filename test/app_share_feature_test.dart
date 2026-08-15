import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/app_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppShareService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('app share constants point to the permanent direct-download URL', () {
    expect(
      AppShareService.directDownloadUrl,
      'https://github.com/AwadhObaid/DalilAlHami-Releases/releases/latest/download/DalilAlHami.apk',
    );
    expect(
      AppShareService.arabicShareText,
      contains(AppShareService.directDownloadUrl),
    );
    expect(
      AppShareService.englishShareText,
      contains(AppShareService.directDownloadUrl),
    );
    expect(AppShareService.arabicShareText, contains('دليل الحامي'));
  });

  test('shareApp sends the exact Android method-channel payload', () async {
    MethodCall? capturedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return null;
    });

    await const AppShareService().shareApp(
      text: '  نص المشاركة  ',
      subject: ' دليل الحامي ',
      chooserTitle: ' مشاركة التطبيق ',
    );

    expect(capturedCall, isNotNull);
    expect(capturedCall!.method, 'shareApp');
    expect(
      capturedCall!.arguments,
      <String, String>{
        'text': 'نص المشاركة',
        'subject': 'دليل الحامي',
        'chooserTitle': 'مشاركة التطبيق',
      },
    );
  });

  test('shareApp rejects empty text before invoking Android', () async {
    var invoked = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return null;
    });

    expect(
      () => const AppShareService().shareApp(
        text: '   ',
        subject: 'دليل الحامي',
        chooserTitle: 'مشاركة التطبيق',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(invoked, isFalse);
  });

  test('native Android share contract uses ACTION_SEND and chooser', () async {
    final source = await File(
      'android/app/src/main/kotlin/com/awadhobaid/dalilalhami/MainActivity.kt',
    ).readAsString();

    expect(source, contains('Intent(Intent.ACTION_SEND)'));
    expect(source, contains('Intent.EXTRA_TEXT'));
    expect(source, contains('Intent.EXTRA_SUBJECT'));
    expect(source, contains('Intent.createChooser'));
    expect(source, contains(AppShareService.channelName));
    expect(source, contains('SHARE_METHOD = "shareApp"'));
  });

  test('settings page exposes the app-share tile and service call', () async {
    final source = await File(
      'lib/features/settings/app_settings_page.dart',
    ).readAsString();

    expect(source, contains("app_share_service.dart"));
    expect(source, contains("settings-share-app"));
    expect(source, contains("title: const Text('مشاركة التطبيق')"));
    expect(source, contains('Icons.share_rounded'));
    expect(source, contains('_shareService.shareApp('));
    expect(source, contains('AppShareService.arabicShareText'));
    expect(source, contains('AppShareService.englishShareText'));
  });
}
