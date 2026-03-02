import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? currentUser;
  AuthState({this.currentUser});

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.role == UserRole.admin;
  bool get isManager => currentUser?.role == UserRole.manager;
  bool get isCashier => currentUser?.role == UserRole.cashier;
  
  /// Managers and Admins both have access to certain administrative features
  bool get hasAdminAccess => isAdmin || isManager;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  void login(UserModel user) {
    state = AuthState(currentUser: user);
  }

  void logout() {
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
