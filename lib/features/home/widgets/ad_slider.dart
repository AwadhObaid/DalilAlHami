import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AdSlider extends StatelessWidget {
  const AdSlider({
    required this.controller,
    required this.advertisements,
    super.key,
  });

  final PageController controller;
  final List<String> advertisements;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.lightTeal,
            AppColors.primaryTeal,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: PageView.builder(
        controller: controller,
        itemCount: advertisements.length,
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              advertisements[index],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
