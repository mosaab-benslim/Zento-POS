import 'package:dbcrypt/dbcrypt.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zento_pos/core/models/user_model.dart';
import 'package:zento_pos/core/database/app_database.dart';
import 'package:flutter/foundation.dart'; // ✅ Added for compute

/// Top-level function for background isolate processing
bool _verifyPinInBackground(Map<String, String> data) {
  final pin = data['pin'];
  final hashed = data['hashed'];
  if (pin == null || hashed == null || pin.isEmpty) return false;
  try {
    return DBCrypt().checkpw(pin, hashed);
  } catch (e) {
    return false;
  }
}

class UserDao {
  
  /// Helper to hash PINs using BCrypt
  String _hashPin(String pin) {
    if (pin.isEmpty) return pin;
    return DBCrypt().hashpw(pin, DBCrypt().gensalt());
  }

  /// Helper to verify PIN in a background Isolate to prevent UI lag
  Future<bool> _verifyPin(String pin, String? hashed) async {
    if (hashed == null || pin.isEmpty) return false;
    return compute(_verifyPinInBackground, {
      'pin': pin,
      'hashed': hashed,
    });
  }

  /// Insert new user (admin or cashier)
  /// Returns false if PIN already exists or error occurs
  Future<bool> insertUser(UserModel user) async {
    final db = await AppDatabase.instance.database;
    try {
      await db.insert(
        'users',
        user.toMap(), // toMap now includes pin_length
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🔴 OLD (kept for backward compatibility if needed)
  /// You can remove this later if unused
  Future<UserModel?> getUserByPin(String pin) async {
    final db = await AppDatabase.instance.database;
    final hashedPin = _hashPin(pin); // Compare HASHES

    final maps = await db.query(
      'users',
      where: 'pin = ?',
      whereArgs: [hashedPin],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  /// ✅ NEW — Role-safe PIN lookup with BCrypt verification
  Future<UserModel?> getUserByPinAndRole(
    String pin,
    UserRole role,
  ) async {
    final db = await AppDatabase.instance.database;
    
    // 1. Fetch user(s) by role first
    final maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role.index],
    );

    if (maps.isNotEmpty) {
      for (var map in maps) {
        final user = UserModel.fromMap(map);
        // 2. Verify PIN using background Isolate
        if (await _verifyPin(pin, user.pinHash)) {
          return user;
        }
      }
    }
    return null;
  }

  /// Get all users (admin panel, future use)
  Future<List<UserModel>> getAllUsers() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('users');
    return result.map((json) => UserModel.fromMap(json)).toList();
  }

  /// Delete a user
  Future<bool> deleteUser(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows > 0;
  }

  /// Update user PIN securely
  Future<bool> updatePin(int userId, String newPin) async {
    final db = await AppDatabase.instance.database;
    final hashedPin = _hashPin(newPin);
    
    final rows = await db.update(
      'users',
      {
        'pin': hashedPin,
        'pin_length': newPin.length, // Update length too
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    return rows > 0;
  }

  /// ✅ NEW — Get expected PIN length for a role to adapt Login UI
  Future<int> getRepresentativePinLength(UserRole role) async {
    final db = await AppDatabase.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      columns: ['pin_length'],
      where: 'role = ?',
      whereArgs: [role.index],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['pin_length'] as int? ?? 4;
    }
    return role == UserRole.admin ? 8 : 4; // Default fallback
  }
}
