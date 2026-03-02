import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ Added for RTL support
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

// ─── REPOSITORY IMPORTS ───
import 'package:zento_pos/core/repositories/user_repository.dart';
import 'package:zento_pos/core/repositories/local_user_repository.dart';
import 'package:zento_pos/core/repositories/product_repository.dart';
import 'package:zento_pos/core/repositories/local_product_repository.dart';
import 'package:zento_pos/core/repositories/category_repository.dart';
import 'package:zento_pos/core/repositories/local_category_repository.dart';
import 'package:zento_pos/core/repositories/order_repository.dart';
import 'package:zento_pos/core/repositories/local_order_repository.dart';
import 'package:zento_pos/core/repositories/app_settings_repository.dart';
import 'package:zento_pos/core/repositories/local_app_settings_repository.dart';

// ─── DATABASE DAO IMPORTS ───
import 'package:zento_pos/core/database/user_dao.dart';
import 'package:zento_pos/core/database/product_dao.dart';
import 'package:zento_pos/core/database/category_dao.dart';
import 'package:zento_pos/core/database/order_dao.dart';
import 'package:zento_pos/core/database/app_settings_dao.dart';
import 'package:zento_pos/core/database/table_dao.dart';
import 'package:zento_pos/core/database/ingredient_dao.dart';
import 'package:zento_pos/core/repositories/table_repository.dart';
import 'package:zento_pos/core/repositories/local_table_repository.dart';
import 'package:zento_pos/core/repositories/ingredient_repository.dart';
import 'package:zento_pos/core/repositories/local_ingredient_repository.dart';

// ─── PROVIDER IMPORTS ───
import 'package:zento_pos/core/providers/language_provider.dart'; 
import 'package:zento_pos/core/providers/printer_provider.dart';
import 'package:zento_pos/core/services/license_service.dart';
import 'package:zento_pos/screens/auth/license_activation_screen.dart';
import 'screens/auth/login_screen.dart';

// ─── GLOBAL PROVIDERS ───
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final userDao = UserDao();
  return LocalUserRepository(userDao);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final productDao = ProductDao();
  return LocalProductRepository(productDao);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final categoryDao = CategoryDao();
  return LocalCategoryRepository(categoryDao);
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final orderDao = OrderDao();
  return LocalOrderRepository(orderDao);
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final appSettingsDao = AppSettingsDao();
  return LocalAppSettingsRepository(appSettingsDao);
});

final tableRepositoryProvider = Provider<TableRepository>((ref) { 
  final tableDao = TableDao();
  return LocalTableRepository(tableDao);
});

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  final ingredientDao = IngredientDao();
  return LocalIngredientRepository(ingredientDao);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      fullScreen: true,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: ZentoPOS()));
}

// ✅ Changed to ConsumerWidget to listen to Language Changes
class ZentoPOS extends ConsumerWidget {
  const ZentoPOS({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 0. Listen to license status
    final license = ref.watch(licenseProvider);

    // 1. Listen to the language provider
    final appLanguage = ref.watch(languageProvider);

    // 2. Initialize Printer Provider (Triggers auto-connect logic)
    ref.watch(printerProvider);

    if (license.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Zento POS',
      
      // 2. Pass the Locale so Flutter knows to flip layout for Arabic
      locale: appLanguage.locale,
      
      // 3. Add Localization delegates for standard Flutter widgets
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF263238),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        // Switch font based on language if needed (e.g. Cairo for Arabic)
        textTheme: _getSafeFontTheme(),
      ),
      home: license.isActivated 
        ? const LoginScreen() 
        : const LicenseActivationScreen(),
    );
  }

  TextTheme _getSafeFontTheme() {
    try {
      return GoogleFonts.interTextTheme();
    } catch (e) {
      debugPrint("Warning: GoogleFonts failed to load: $e");
      return const TextTheme(); // Fallback to system fonts
    }
  }
}
