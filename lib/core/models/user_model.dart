// lib/core/models/user_model.dart

/// ✅ ENUM — stored as int in DB
/// admin = 0, cashier = 1, manager = 2
enum UserRole { admin, cashier, manager }

class UserModel {
  final int? id;
  final String name;
  final String pinHash;
  final int pinLength; // ✅ Added to track plain text length for UI purposes
  final UserRole role;

  const UserModel({
    this.id,
    required this.name,
    required this.pinHash,
    required this.pinLength,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pin': pinHash,
      'pin_length': pinLength, // New column
      'role': role.index,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      pinHash: map['pin'] as String,
      pinLength: map['pin_length'] as int? ?? 4, // Default to 4 if null
      role: UserRole.values[map['role'] as int],
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? pinHash,
    int? pinLength,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pinHash: pinHash ?? this.pinHash,
      pinLength: pinLength ?? this.pinLength,
      role: role ?? this.role,
    );
  }
}
