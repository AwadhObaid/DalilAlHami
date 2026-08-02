import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'ابحث عن خدمة أو محل...',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            prefixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primaryTeal,
                    ),
                    onPressed: onClear,
                  )
                : const Padding(
                    padding: EdgeInsets.only(
                      left: 15,
                      right: 10,
                    ),
                    child: Icon(
                      Icons.search,
                      color: AppColors.primaryTeal,
                      size: 28,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }
}
