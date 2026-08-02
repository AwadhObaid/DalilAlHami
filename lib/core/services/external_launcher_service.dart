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

  static Future<bool> openWhatsApp(String phoneNumber) async {
    final formattedNumber = _normalizeYemenPhone(phoneNumber);
    if (formattedNumber.isEmpty) {
      return false;
    }

    final appUri = Uri.parse(
      'whatsapp://send?phone=$formattedNumber',
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
      // ننتقل للرابط الخارجي عند عدم توفر التطبيق.
    }

    final webUri = Uri.https(
      'wa.me',
      '/$formattedNumber',
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

  static String _normalizeYemenPhone(String phoneNumber) {
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
