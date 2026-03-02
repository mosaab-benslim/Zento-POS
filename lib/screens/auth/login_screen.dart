import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/main.dart'; // For userRepositoryProvider
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/screens/home/order_screen.dart';
import 'package:zento_pos/core/repositories/user_repository.dart';
import 'package:zento_pos/core/models/user_model.dart';
import 'package:zento_pos/screens/admin/admin_dashboard.dart';

// IMPORTANT: Import your language provider file here
import 'package:zento_pos/core/providers/language_provider.dart'; 
import 'package:zento_pos/core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum LoginStatus { initial, success, error }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _pin = "";
  UserRole _selectedRole = UserRole.cashier;
  // ❌ REMOVED: AppLanguage _language... (We now use the Provider)
  
  LoginStatus _loginStatus = LoginStatus.initial;
  final FocusNode _focusNode = FocusNode();
  int _expectedPinLength = 4; // Default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _updateExpectedPinLength();
    });
  }

  Future<void> _updateExpectedPinLength() async {
    final repo = ref.read(userRepositoryProvider);
    final length = await repo.getRepresentativePinLength(_selectedRole);
    if (mounted) {
      setState(() {
        _expectedPinLength = length;
        _pin = ""; // Reset PIN when role or length changes
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ───────────────── TRANSLATIONS ─────────────────

  final Map<String, Map<AppLanguage, String>> _textData = {
    'brand_name': {
      AppLanguage.en: 'Zento POS',
      AppLanguage.fr: 'Zento POS',
      AppLanguage.ar: 'Zento POS'
    },
    'brand_slogan': {
      AppLanguage.en: 'Fast. Stable. Offline.',
      AppLanguage.fr: 'Rapide. Stable. Hors ligne.',
      AppLanguage.ar: 'سريع . آمن . بدون إنترنت'
    },
    'enter_pin': {
      AppLanguage.en: 'Enter Staff PIN',
      AppLanguage.fr: 'Entrez le code PIN',
      AppLanguage.ar: 'أدخل رمز المرور'
    },
    'enter_admin_pin': {
      AppLanguage.en: 'Enter Admin PIN',
      AppLanguage.fr: 'Entrez le code Admin',
      AppLanguage.ar: 'أدخل رمز المسؤول'
    },
    'enter_manager_pin': {
      AppLanguage.en: 'Enter Manager PIN',
      AppLanguage.fr: 'Entrez le code Gérant',
      AppLanguage.ar: 'أدخل رمز المدير'
    },
    'enter_cashier_pin': {
      AppLanguage.en: 'Enter Cashier PIN',
      AppLanguage.fr: 'Entrez le code Caissier',
      AppLanguage.ar: 'أدخل رمز الكاشير'
    },
    'verifying': {
      AppLanguage.en: 'Verifying...',
      AppLanguage.fr: 'Vérification...',
      AppLanguage.ar: 'جاري التحقق...'
    },
    'success': {
      AppLanguage.en: 'Success!',
      AppLanguage.fr: 'Succès!',
      AppLanguage.ar: 'تم بنجاح!'
    },
    'error': {
      AppLanguage.en: 'Invalid PIN',
      AppLanguage.fr: 'PIN Invalide',
      AppLanguage.ar: 'رمز خاطئ'
    },
    'admin': {
      AppLanguage.en: 'Admin',
      AppLanguage.fr: 'Admin',
      AppLanguage.ar: 'مسؤول'
    },
    'manager': {
      AppLanguage.en: 'Manager',
      AppLanguage.fr: 'Gérant',
      AppLanguage.ar: 'مدير'
    },
    'cashier': {
      AppLanguage.en: 'Cashier',
      AppLanguage.fr: 'Caissier',
      AppLanguage.ar: 'كاشير'
    }
  };

  // Helper to get text based on current Global Language
  String _t(String key) {
    final currentLang = ref.watch(languageProvider);
    return _textData[key]?[currentLang] ?? "";
  }

  void _cycleLanguage() {
    // 1. Read current language
    final current = ref.read(languageProvider);
    
    // 2. Determine next language
    final next = current == AppLanguage.en
        ? AppLanguage.fr
        : current == AppLanguage.fr
            ? AppLanguage.ar
            : AppLanguage.en;
            
    // 3. Update the Global Provider (This updates ALL screens)
    ref.read(languageProvider.notifier).setLanguage(next);
  }

  // ───────────────── PIN INPUT ─────────────────

  void _onDigitPress(String digit) {
    if (_pin.length < _expectedPinLength) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == _expectedPinLength) {
        _attemptLogin(silent: true);
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _loginStatus = LoginStatus.initial;
      });
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _onBackspace();
      } else if (event.logicalKey == LogicalKeyboardKey.enter || 
                 event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_pin.length > 0) { // Allow trying whatever is entered
          _attemptLogin(silent: false);
        }
      } else if (event.character != null &&
          int.tryParse(event.character!) != null) {
        _onDigitPress(event.character!);
      }
    }
  }

  // ───────────────── LOGIN LOGIC ─────────────────

  Future<void> _attemptLogin({bool silent = false}) async {
    if (!silent) {
      scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Verifying...'),
          backgroundColor: Color(0xFF263238),
          duration: Duration(milliseconds: 500),
        ),
      );
    }

    if (!silent) {
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;

    final repo = ProviderScope.containerOf(context).read(userRepositoryProvider);
    final user = await repo.loginByPin(pin: _pin, role: _selectedRole);

    if (user == null) {
      if (!silent || _pin.length >= _expectedPinLength) { // Show error if max length reached or explicit login attempt
        _showError();
      }
      return;
    }

    setState(() => _loginStatus = LoginStatus.success);
    
    // 🔥 Store user session
    ref.read(authProvider.notifier).login(user);

    // ⚡ Snappy delay (300ms) to show the "Success" state before moving
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _selectedRole == UserRole.cashier
            ? const OrderScreen()
            : const AdminDashboard(),
      ),
    );
  }

  void _showError() {
    setState(() => _loginStatus = LoginStatus.error);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _pin = "";
          _loginStatus = LoginStatus.initial;
        });
      }
    });
  }

  void _setLoginMode(UserRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _pin = "";
      _loginStatus = LoginStatus.initial;
    });
    // 🔥 Force immediate UI update for dots
    _updateExpectedPinLength();
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    // WATCH the provider. If Admin Dashboard changes language, this screen updates too.
    final currentLang = ref.watch(languageProvider);
    final bool isRtl = currentLang == AppLanguage.ar;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          body: Row(
            children: [
              // LEFT branding
              Expanded(
                flex: 4,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Color(0xFF263238),
                  ),
                  child: Stack(
                    children: [
                      // 🔹 Premium Gradient Background
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topLeft,
                              radius: 1.5,
                              colors: [
                                Color(0xFF37474F), // Lighter BlueGrey
                                Color(0xFF263238), // Dark BlueGrey
                                Color(0xFF102027), // Almost Black
                              ],
                              stops: [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      
                      // 🔹 Subtle Abstract Shapes (Professional Look)
                      Positioned(
                        top: -100,
                        left: -50,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -50,
                        right: -50,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.02),
                          ),
                        ),
                      ),

                      // 🔹 MAIN CONTENT
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05), // Glassy feel
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.point_of_sale, 
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              "Zento POS", // ✅ Updated rebranding
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _t('brand_slogan'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT panel
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loginStatus == LoginStatus.error
                                  ? _t('error')
                                  : _loginStatus == LoginStatus.success
                                      ? _t('success')
                                  : _selectedRole == UserRole.admin
                                      ? _t('enter_admin_pin')
                                      : _selectedRole == UserRole.manager
                                          ? _t('enter_manager_pin')
                                          : _t('enter_cashier_pin'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _loginStatus == LoginStatus.error
                                    ? Colors.red
                                    : _loginStatus == LoginStatus.success
                                        ? Colors.green
                                        : Colors.blueGrey[900],
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildPinDots(),
                            const SizedBox(height: 40),
                            _buildKeypad(),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: _buildRoleSelector(),
                    ),
                    Positioned(
                      top: 24,
                      right: isRtl ? null : 24,
                      left: isRtl ? 24 : null,
                      child: _buildLanguageButton(currentLang),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── HELPERS ─────────────────

  Widget _buildPinDots() {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_expectedPinLength, (index) {
          final filled = index < _pin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: filled ? 24 : 18,
            height: filled ? 24 : 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _loginStatus == LoginStatus.error
                  ? Colors.red
                  : _loginStatus == LoginStatus.success
                      ? Colors.green
                      : filled
                          ? const Color(0xFF1E293B)
                          : Colors.grey[300],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeypad() {
    return SizedBox(
      width: 340,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: 12, // 3 rows of 3, plus 0, backspace, and an empty slot
        itemBuilder: (context, index) {
          if (index < 9) {
            return _buildKeyButton("${index + 1}"); // Numbers 1-9
          } else if (index == 9) {
            return const SizedBox.shrink(); // Empty slot
          } else if (index == 10) {
            return _buildKeyButton("0"); // Number 0
          } else { // index == 11
            return _buildBackspaceButton(); // Backspace
          }
        },
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roleButton(UserRole.cashier, Icons.point_of_sale, _t('cashier')),
        const SizedBox(width: 12),
        _roleButton(UserRole.manager, Icons.supervisor_account, _t('manager')),
        const SizedBox(width: 12),
        _roleButton(UserRole.admin, Icons.admin_panel_settings, _t('admin')),
      ],
    );
  }

  Widget _roleButton(UserRole role, IconData icon, String label) {
    bool isSel = _selectedRole == role;
    return Material(
      color: isSel ? const Color(0xFF1E293B) : Colors.white,
      elevation: isSel ? 4 : 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _setLoginMode(role),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSel ? Colors.white : Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : Colors.blueGrey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleDeco(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildLanguageButton(AppLanguage currentLang) {
    return InkWell(
      onTap: _cycleLanguage,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.language, size: 20, color: Colors.blueGrey[700]),
            const SizedBox(width: 8),
            Text(
              currentLang == AppLanguage.en
                  ? "English"
                  : currentLang == AppLanguage.fr
                      ? "Français"
                      : "العربية",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _onDigitPress(label),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _onBackspace,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Icon(Icons.backspace_rounded,
              size: 28, color: Colors.red[400]),
        ),
      ),
    );
  }
}
