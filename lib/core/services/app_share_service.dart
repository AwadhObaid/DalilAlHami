import 'package:flutter/services.dart';

class AppShareService {
  const AppShareService();

  static const String channelName = 'com.awadhobaid.dalilalhami/app_share';
  static const String appName = 'دليل الحامي';
  static const String directDownloadUrl =
      'https://github.com/AwadhObaid/DalilAlHami-Releases/releases/latest/download/DalilAlHami.apk';

  static const String arabicShareText =
      'حمّل تطبيق دليل الحامي، دليلك للخدمات والأنشطة المحلية في مدينة الحامي.\n'
      'رابط التطبيق:\n'
      'https://github.com/AwadhObaid/DalilAlHami-Releases/releases/latest/download/DalilAlHami.apk';

  static const String englishShareText =
      'Download Dalil Al Hami, your guide to local services and activities.\n'
      'App link:\n'
      'https://github.com/AwadhObaid/DalilAlHami-Releases/releases/latest/download/DalilAlHami.apk';

  static const MethodChannel _channel = MethodChannel(channelName);

  Future<void> shareApp({
    required String text,
    required String subject,
    required String chooserTitle,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const FormatException('Share text must not be empty.');
    }

    await _channel.invokeMethod<void>(
      'shareApp',
      <String, String>{
        'text': normalizedText,
        'subject': subject.trim(),
        'chooserTitle': chooserTitle.trim(),
      },
    );
  }
}
