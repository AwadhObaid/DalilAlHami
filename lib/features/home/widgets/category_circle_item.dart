import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/service_category.dart';

class CategoryCircleItem extends StatelessWidget {
  const CategoryCircleItem({
    required this.category,
    required this.onTap,
    super.key,
  });

  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryTeal,
              child: Icon(
                category.icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
