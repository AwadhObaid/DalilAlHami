import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/launch_actions.dart';
import '../../models/business.dart';

class MemberDetailsPage extends StatelessWidget {
  const MemberDetailsPage({
    required this.business,
    super.key,
  });

  final Business business;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(business.name),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              child: const Icon(
                Icons.person,
                size: 100,
                color: AppColors.primaryTeal,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoTile(
                    Icons.category,
                    'القسم',
                    business.category,
                  ),
                  _buildInfoTile(
                    Icons.location_on,
                    'الموقع',
                    business.place,
                  ),
                  _buildInfoTile(
                    Icons.phone,
                    'رقم التواصل',
                    business.phone,
                  ),
                  if (business.details.isNotEmpty)
                    _buildInfoTile(
                      Icons.description,
                      'الوصف',
                      business.details,
                    ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            LaunchActions.openWhatsApp(
                              context,
                              business.whatsapp.isNotEmpty
                                  ? business.whatsapp
                                  : business.phone,
                            );
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('واتساب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            LaunchActions.makePhoneCall(
                              context,
                              business.phone,
                            );
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.lightTeal,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
