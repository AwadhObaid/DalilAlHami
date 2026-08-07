import 'package:flutter/material.dart' hide Text;

import 'package:hami_guide/core/localization/app_localized_text.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/utils/launch_actions.dart';
import '../profile/profile_page.dart';

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  final GoogleAuthService _authService = const GoogleAuthService();
  final AuthSessionStore _authStore = AuthSessionStore.instance;

  bool _isOpeningGoogle = false;
  bool _waitingForCallback = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _authStore.addListener(_handleAuthChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthChanged();
    });
  }

  @override
  void dispose() {
    _authStore.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted || !_authStore.isAuthenticated || _didNavigate) {
      return;
    }

    _didNavigate = true;

    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (context) => const ProfilePage(),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_isOpeningGoogle) {
      return;
    }

    setState(() {
      _isOpeningGoogle = true;
    });

    try {
      final opened = await _authService.signIn();

      if (!mounted) {
        return;
      }

      setState(() {
        _waitingForCallback = opened;
      });

      if (!opened) {
        _showMessage(
          'تعذر فتح صفحة Google على الجهاز.',
          isError: true,
        );
      }
    } on GoogleAuthFailure catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningGoogle = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.bindToTheme(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            children: [
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(
                    alpha: 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_business_outlined,
                  size: 62,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'أضف نشاطك إلى دليل الحامي',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'سجّل بحساب Google ثم أرسل بيانات نشاط واحد '
                'للمراجعة. لن يظهر النشاط للعامة قبل اعتماد الإدارة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.6,
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 28),
              _buildFeature(
                Icons.person_outline,
                'كل مستخدم يدير نشاطه فقط',
              ),
              _buildFeature(
                Icons.fact_check_outlined,
                'الإدارة تراجع الطلب قبل النشر',
              ),
              _buildFeature(
                Icons.lock_outline,
                'بياناتك محمية بصلاحيات Supabase',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isOpeningGoogle ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    side: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: _isOpeningGoogle
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                          ),
                        )
                      : const Icon(
                          Icons.account_circle_outlined,
                          color: AppColors.primaryTeal,
                        ),
                  label: const Text(
                    'المتابعة باستخدام Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (_waitingForCallback) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'أكمل اختيار حساب Google في المتصفح، '
                    'ثم ستعود إلى التطبيق تلقائيًا.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  LaunchActions.openWhatsApp(
                    context,
                    '772551846',
                  );
                },
                icon: const Icon(
                  Icons.chat_outlined,
                  color: Colors.green,
                ),
                label: const Text(
                  'إرسال طلب الإضافة للإدارة عبر واتساب',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.lightTeal.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primaryTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
