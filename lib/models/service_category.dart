import 'package:flutter/material.dart';

enum CategoryDisplayGroup {
  services,
  transport;

  static CategoryDisplayGroup fromDatabase(String? value) {
    return value == 'transport'
        ? CategoryDisplayGroup.transport
        : CategoryDisplayGroup.services;
  }

  String get databaseValue => switch (this) {
        CategoryDisplayGroup.services => 'services',
        CategoryDisplayGroup.transport => 'transport',
      };
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    required this.sortOrder,
    required this.displayGroup,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String iconName;
  final int sortOrder;
  final CategoryDisplayGroup displayGroup;
  final String? imageUrl;

  IconData get icon => iconFromName(iconName);

  bool get isTransport => displayGroup == CategoryDisplayGroup.transport;

  factory ServiceCategory.fromSupabase(
    Map<String, dynamic> data,
  ) {
    return ServiceCategory(
      id: data['id']?.toString() ?? '',
      name: data['name_ar']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      iconName: data['icon_name']?.toString() ?? 'category',
      sortOrder: (data['sort_order'] as num?)?.toInt() ?? 0,
      displayGroup: CategoryDisplayGroup.fromDatabase(
        data['display_group']?.toString(),
      ),
      imageUrl: _nullableString(data['image_url']),
    );
  }

  static IconData iconFromName(String iconName) {
    return switch (iconName) {
      'emergency' => Icons.emergency,
      'local_pharmacy' => Icons.local_pharmacy,
      'medical_services' => Icons.medical_services,
      'restaurant' => Icons.restaurant,
      'soup_kitchen' => Icons.soup_kitchen,
      'fastfood' => Icons.fastfood,
      'inventory' => Icons.inventory,
      'phishing' => Icons.phishing,
      'devices' => Icons.devices,
      'home_repair_service' => Icons.home_repair_service,
      'storefront' => Icons.storefront,
      'local_gas_station' => Icons.local_gas_station,
      'groups' => Icons.groups,
      'content_cut' => Icons.content_cut,
      'build' => Icons.build,
      'local_laundry_service' => Icons.local_laundry_service,
      'engineering' => Icons.engineering,
      'water_drop' => Icons.water_drop,
      'local_shipping' => Icons.local_shipping,
      'electric_rickshaw' => Icons.electric_rickshaw,
      'airport_shuttle' => Icons.airport_shuttle,
      'local_taxi' => Icons.local_taxi,
      'motorcycle' => Icons.motorcycle,
      _ => Icons.category,
    };
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
