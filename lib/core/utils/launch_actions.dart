import 'package:flutter/material.dart';

import '../services/external_launcher_service.dart';

abstract final class LaunchActions {
  static Future<void> makePhoneCall(
    BuildContext context,
    String phoneNumber,
  ) async {
    final opened = await ExternalLauncherService.makePhoneCall(phoneNumber);

    if (!context.mounted || opened) {
      return;
    }

    _showFailure(
      context,
      'تعذر فتح تطبيق الاتصال.',
    );
  }

  static Future<void> openWhatsApp(
    BuildContext context,
    String phoneNumber,
  ) async {
    final opened = await ExternalLauncherService.openWhatsApp(phoneNumber);

    if (!context.mounted || opened) {
      return;
    }

    _showFailure(
      context,
      'تعذر فتح واتساب. تأكد من تثبيت التطبيق أو المتصفح.',
    );
  }

  static void _showFailure(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
