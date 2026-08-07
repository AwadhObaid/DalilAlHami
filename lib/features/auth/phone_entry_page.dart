import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import 'otp_page.dart';

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continueToOtp() {
    final phone = _phoneController.text.trim();

    if (phone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل رقم هاتف صحيحًا.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => OtpPage(phoneNumber: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    size: 46,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'مرحبًا بك في دليل الحامي',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'أدخل رقم هاتفك للمتابعة وإدارة نشاطك داخل الدليل.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outline),
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('رقم الهاتف', style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _phoneController,
                      autofocus: true,
                      textAlign: TextAlign.left,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onSubmitted: (_) => _continueToOtp(),
                      decoration: const InputDecoration(
                        hintText: '77xxxxxxx',
                        prefixIcon: Icon(Icons.phone_outlined),
                        suffixText: '+967',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: _continueToOtp,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('إرسال رمز التحقق'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'هذه شاشة تحقق تجريبية حاليًا، وسيتم ربطها لاحقًا بخدمة المصادقة.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
