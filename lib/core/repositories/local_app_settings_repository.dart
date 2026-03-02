// lib/core/repositories/local_app_settings_repository.dart
import '../database/app_settings_dao.dart';
import '../models/app_settings_model.dart';
import 'app_settings_repository.dart';

class LocalAppSettingsRepository implements AppSettingsRepository {
  final AppSettingsDao _appSettingsDao;

  LocalAppSettingsRepository(this._appSettingsDao);

  @override
  Future<AppSettings?> getSettings() {
    return _appSettingsDao.getSettings();
  }

  @override
  Future<void> updateSettings(AppSettings settings) {
    return _appSettingsDao.updateSettings(settings);
  }
}
