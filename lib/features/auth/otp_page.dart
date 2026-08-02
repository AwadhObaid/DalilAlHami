import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../profile/profile_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({
    required this.phoneNumber,
    super.key,
  });

  final String phoneNumber;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _confirmMockOtp() {
    if (_otpController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل رمزًا من 4 أرقام.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'التحقق من الرمز',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'تم إرسال الرمز إلى الرقم ',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontFamily: 'Tajawal',
                  ),
                  children: [
                    TextSpan(
                      text: '+967 ${widget.phoneNumber}',
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _otpController,
                textAlign: TextAlign.center,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 15,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '----',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    letterSpacing: 15,
                  ),
                  fillColor: Colors.grey[50],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: AppColors.primaryTeal,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(
                    double.infinity,
                    55,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                onPressed: _confirmMockOtp,
                child: const Text(
                  'تأكيد الدخول',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'لم يصلك الرمز؟ ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم إعادة إرسال الرمز التجريبي',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'أعد الإرسال',
                      style: TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
