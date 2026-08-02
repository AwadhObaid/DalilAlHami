import 'package:flutter/material.dart';

import '../../models/service_category.dart';

abstract final class AppCatalog {
  static const List<String> advertisements = [
    'مساحة إعلانية مميزة 1',
    'تخفيضات كبرى في قسم البناء',
    'سجل الآن في الدليل مجاناً',
  ];

  static const List<ServiceCategory> services = [
    ServiceCategory(name: 'طوارئ', icon: Icons.emergency),
    ServiceCategory(name: 'صيدليات', icon: Icons.local_pharmacy),
    ServiceCategory(name: 'عيادات', icon: Icons.medical_services),
    ServiceCategory(name: 'مطاعم', icon: Icons.restaurant),
    ServiceCategory(name: 'مطابخ', icon: Icons.soup_kitchen),
    ServiceCategory(name: 'بوفيات', icon: Icons.fastfood),
    ServiceCategory(name: 'محلات جملة', icon: Icons.inventory),
    ServiceCategory(name: 'صيد/أدوات بحر', icon: Icons.phishing),
    ServiceCategory(name: 'إلكترونيات', icon: Icons.devices),
    ServiceCategory(name: 'مواد بناء', icon: Icons.home_repair_service),
    ServiceCategory(name: 'بقالات', icon: Icons.storefront),
    ServiceCategory(name: 'محطات', icon: Icons.local_gas_station),
    ServiceCategory(name: 'أعمال أخرى', icon: Icons.groups),
    ServiceCategory(name: 'صوالين', icon: Icons.content_cut),
    ServiceCategory(name: 'ورش متنوعة', icon: Icons.build),
    ServiceCategory(
      name: 'مغاسل متنوعة',
      icon: Icons.local_laundry_service,
    ),
  ];

  static const List<ServiceCategory> transport = [
    ServiceCategory(name: 'معدات عمل', icon: Icons.engineering),
    ServiceCategory(name: 'بوز ماء', icon: Icons.water_drop),
    ServiceCategory(name: 'سيارات نقل', icon: Icons.local_shipping),
    ServiceCategory(name: 'تكاتك', icon: Icons.electric_rickshaw),
    ServiceCategory(name: 'سيارات نوها', icon: Icons.airport_shuttle),
    ServiceCategory(name: 'تكاسي', icon: Icons.local_taxi),
    ServiceCategory(name: 'دراجات توصيل', icon: Icons.motorcycle),
  ];

  static List<ServiceCategory> get allCategories => [
        ...services,
        ...transport,
      ];
}
