import 'package:flutter/material.dart';

import '../services/external_launcher_service.dart';

abstract final class LaunchActions {
  static Future<void> makePhoneCall(
    BuildContext context,
    String phoneNumber,
  ) async {
    if (phoneNumber.trim().isEmpty) {
      _showFailure(
        context,
        'لا يتوفر رقم اتصال لهذا النشاط.',
      );
      return;
    }

    final opened = await ExternalLauncherService.makePhoneCall(phoneNumber);

    if (!context.mounted || opened) {
      return;
    }

    _showFailure(
      context,
      'تعذر فتح تطبيق الاتصال.',
    );
  }

  static Future<void> openExternalUrl(
    BuildContext context,
    String value,
  ) async {
    final opened = await ExternalLauncherService.openExternalUrl(value);

    if (!context.mounted || opened) {
      return;
    }

    _showFailure(
      context,
      'تعذر فتح رابط الإعلان.',
    );
  }

  static Future<void> openWhatsApp(
    BuildContext context,
    String phoneNumber, {
    String? message,
  }) async {
    if (phoneNumber.trim().isEmpty) {
      _showFailure(
        context,
        'لا يتوفر رقم واتساب لهذا النشاط.',
      );
      return;
    }

    final opened = await ExternalLauncherService.openWhatsApp(
      phoneNumber,
      message: message,
    );

    if (!context.mounted || opened) {
      return;
    }

    _showFailure(
      context,
      'تعذر فتح واتساب. تأكد من تثبيت التطبيق أو المتصفح.',
    );
  }

  static void showMessage(
    BuildContext context,
    String message,
  ) {
    _showFailure(context, message);
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
