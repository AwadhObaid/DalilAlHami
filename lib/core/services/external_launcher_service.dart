import 'package:url_launcher/url_launcher.dart';

abstract final class ExternalLauncherService {
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      return false;
    }

    final uri = Uri(
      scheme: 'tel',
      path: normalizedPhone,
    );

    try {
      return launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }

  static Future<bool> openExternalUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    try {
      return launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }

  static Future<bool> openWhatsApp(
    String phoneNumber, {
    String? message,
  }) async {
    final formattedNumber = normalizeYemenPhone(phoneNumber);
    if (formattedNumber.isEmpty) {
      return false;
    }

    final queryParameters = <String, String>{
      'phone': formattedNumber,
      if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
    };

    final appUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: queryParameters,
    );

    try {
      final appOpened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (appOpened) {
        return true;
      }
    } on Exception {
      // ننتقل إلى الرابط الخارجي عند عدم توفر تطبيق واتساب.
    }

    final webUri = Uri.https(
      'wa.me',
      '/$formattedNumber',
      message != null && message.trim().isNotEmpty
          ? <String, String>{'text': message.trim()}
          : null,
    );

    try {
      return launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      return false;
    }
  }

  static String normalizeYemenPhone(String phoneNumber) {
    var digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.isNotEmpty && !digits.startsWith('967')) {
      digits = '967$digits';
    }

    return digits;
  }
}
