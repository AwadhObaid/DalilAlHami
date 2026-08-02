import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/business.dart';

class LocalDirectoryStore extends ChangeNotifier {
  LocalDirectoryStore._();

  static final LocalDirectoryStore instance = LocalDirectoryStore._();

  final List<Business> _businesses = [
    const Business(
      id: 'seed-pharmacy-1',
      name: 'صيدلية الحامي الحديثة',
      phone: '777111222',
      category: 'صيدليات',
      place: 'بجانب المستشفى',
    ),
    const Business(
      id: 'seed-restaurant-1',
      name: 'مطعم وادي سبأ',
      phone: '777333444',
      category: 'مطاعم',
      place: 'الشارع العام',
    ),
    const Business(
      id: 'seed-tuktuk-1',
      name: 'تكتك السعيد',
      phone: '777555111',
      category: 'تكاتك',
      place: 'السوق',
    ),
  ];

  String? _currentUserBusinessId;

  UnmodifiableListView<Business> get businesses =>
      UnmodifiableListView(_businesses);

  bool get isSubscribed => _currentUserBusinessId != null;

  Business? get currentUserBusiness {
    final id = _currentUserBusinessId;
    if (id == null) {
      return null;
    }

    for (final business in _businesses) {
      if (business.id == id) {
        return business;
      }
    }

    return null;
  }

  List<Business> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return _businesses.where((business) {
      return business.name.toLowerCase().contains(normalizedQuery) ||
          business.category.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  List<Business> byCategory(String categoryName) {
    return _businesses
        .where((business) => business.category == categoryName)
        .toList(growable: false);
  }

  void saveCurrentUserBusiness({
    required String name,
    required String phone,
    required String whatsapp,
    required String category,
    required String details,
    String? imagePath,
  }) {
    final currentId = _currentUserBusinessId;

    if (currentId == null) {
      final newBusiness = Business(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: phone.trim(),
        whatsapp: whatsapp.trim(),
        category: category,
        place: 'الحامي',
        details: details.trim(),
        imagePath: imagePath,
      );

      _businesses.add(newBusiness);
      _currentUserBusinessId = newBusiness.id;
      notifyListeners();
      return;
    }

    final index = _businesses.indexWhere(
      (business) => business.id == currentId,
    );

    if (index == -1) {
      _currentUserBusinessId = null;
      saveCurrentUserBusiness(
        name: name,
        phone: phone,
        whatsapp: whatsapp,
        category: category,
        details: details,
        imagePath: imagePath,
      );
      return;
    }

    _businesses[index] = _businesses[index].copyWith(
      name: name.trim(),
      phone: phone.trim(),
      whatsapp: whatsapp.trim(),
      category: category,
      place: 'الحامي',
      details: details.trim(),
      imagePath: imagePath,
    );
    notifyListeners();
  }

  void deleteCurrentUserBusiness() {
    final currentId = _currentUserBusinessId;
    if (currentId == null) {
      return;
    }

    _businesses.removeWhere((business) => business.id == currentId);
    _currentUserBusinessId = null;
    notifyListeners();
  }
}
