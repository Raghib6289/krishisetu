enum UserRole {
  farmer,
  buyer,
  driver,
  guest;

  String get displayName {
    switch (this) {
      case UserRole.farmer:
        return 'Farmer / Producer';
      case UserRole.buyer:
        return 'Bulk Buyer / Retailer';
      case UserRole.driver:
        return 'Logistics Driver';
      case UserRole.guest:
        return 'Guest';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'farmer':
        return UserRole.farmer;
      case 'buyer':
        return UserRole.buyer;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.farmer;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String location;
  final String token;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.location,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.fromString(json['user_type']),
      location: json['location'] ?? 'Nashik, Maharashtra',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'user_type': role.name,
        'location': location,
        'token': token,
      };
}
