class Business {
  const Business({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.place,
    this.whatsapp = '',
    this.details = '',
    this.imagePath,
  });

  final String id;
  final String name;
  final String phone;
  final String whatsapp;
  final String category;
  final String place;
  final String details;
  final String? imagePath;

  Business copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? category,
    String? place,
    String? details,
    String? imagePath,
    bool clearImagePath = false,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      category: category ?? this.category,
      place: place ?? this.place,
      details: details ?? this.details,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'category': category,
      'place': place,
      'details': details,
      'image_path': imagePath,
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      place: map['place']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      imagePath: map['image_path']?.toString(),
    );
  }
}
