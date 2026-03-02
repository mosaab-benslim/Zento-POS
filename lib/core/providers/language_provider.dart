import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends Notifier<AppLanguage> {
  static const _key = 'app_language';

  @override
  AppLanguage build() {
    _loadSync(); // Trigger async load
    return AppLanguage.en; // Initial default
  }

  Future<void> _loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index != null && index < AppLanguage.values.length) {
      state = AppLanguage.values[index];
    }
  }

  Future<void> setLanguage(AppLanguage value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.index);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

// Helper for UI to get Locales
extension AppLanguageExtension on AppLanguage {
  Locale get locale {
    switch (this) {
      case AppLanguage.ar: return const Locale('ar');
      case AppLanguage.fr: return const Locale('fr');
      default: return const Locale('en');
    }
  }
  
  String get label {
    switch (this) {
      case AppLanguage.ar: return 'العربية';
      case AppLanguage.fr: return 'Français';
      default: return 'English';
    }
  }
}
