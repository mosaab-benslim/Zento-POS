// lib/core/repositories/app_settings_repository.dart
import '../models/app_settings_model.dart';

abstract class AppSettingsRepository {
  Future<AppSettings?> getSettings();
  Future<void> updateSettings(AppSettings settings);
}
