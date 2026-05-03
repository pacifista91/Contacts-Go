class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final String nickname;
  final String phone;
  final String email;
  final String organization;
  final String note;
  final bool isFavorite;
  final int updatedAt;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.organization,
    required this.note,
    this.isFavorite = false,
    required this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      nickname: json['nickname'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      organization: json['organization'] ?? '',
      note: json['note'] ?? '',
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      updatedAt: json['updated_at'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'nickname': nickname,
      'phone': phone,
      'email': email,
      'organization': organization,
      'note': note,
      'is_favorite': isFavorite,
      'updated_at': updatedAt,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  Contact copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? nickname,
    String? phone,
    String? email,
    String? organization,
    String? note,
    bool? isFavorite,
    int? updatedAt,
  }) {
    return Contact(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      organization: organization ?? this.organization,
      note: note ?? this.note,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
