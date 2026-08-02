import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        top: 35,
        bottom: 8,
      ),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(35),
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/logo.png',
          height: 60,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 40,
            );
          },
        ),
      ),
    );
  }
}
