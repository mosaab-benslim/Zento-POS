// lib/core/database/app_settings_dao.dart
import 'package:sqflite/sqflite.dart';
import '../models/app_settings_model.dart';
import 'app_database.dart';

class AppSettingsDao {
  final dbProvider = AppDatabase.instance;

  Future<AppSettings?> getSettings() async {
    final db = await dbProvider.database;
    final maps = await db.query('app_settings', limit: 1);
    
    if (maps.isNotEmpty) {
      return AppSettings.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await dbProvider.database;
    await db.update(
      'app_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }
}
