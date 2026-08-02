import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/launch_actions.dart';
import '../../data/local_directory_store.dart';
import '../directory/member_details_page.dart';

class CategoryListPage extends StatelessWidget {
  const CategoryListPage({
    required this.categoryName,
    super.key,
  });

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final businesses = LocalDirectoryStore.instance.byCategory(categoryName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: AppColors.primaryTeal,
        centerTitle: true,
      ),
      body: businesses.isEmpty
          ? Center(
              child: Text(
                'لا توجد بيانات حالياً في قسم $categoryName',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: businesses.length,
              itemBuilder: (context, index) {
                final business = businesses[index];

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => MemberDetailsPage(
                            business: business,
                          ),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryTeal.withValues(
                        alpha: 0.1,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    title: Text(
                      business.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(business.place),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: AppColors.lightTeal.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.phone,
                          color: AppColors.primaryTeal,
                        ),
                        onPressed: () {
                          LaunchActions.makePhoneCall(
                            context,
                            business.phone,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
