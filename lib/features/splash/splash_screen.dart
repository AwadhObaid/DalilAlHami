import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/directory_data_store.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      DirectoryDataStore.instance.load(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryTeal,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.store,
                    size: 80,
                    color: Colors.white,
                  );
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'أهلاً بك في التطبيق',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'دليلك السريع للوصول إلى الأرقام بكل سهولة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: AppColors.lightTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
