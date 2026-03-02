import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/hardware_info.dart';

class LicenseState {
  final bool isActivated;
  final String machineId;
  final bool isLoading;

  LicenseState({
    this.isActivated = false,
    this.machineId = '',
    this.isLoading = true,
  });

  LicenseState copyWith({bool? isActivated, String? machineId, bool? isLoading}) {
    return LicenseState(
      isActivated: isActivated ?? this.isActivated,
      machineId: machineId ?? this.machineId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LicenseNotifier extends Notifier<LicenseState> {
  @override
  LicenseState build() {
    // Start check immediately
    Future.microtask(() => checkLicense());
    return LicenseState();
  }

  Future<void> checkLicense() async {
    state = state.copyWith(isLoading: true);
    final mId = await HardwareInfo.getMachineId();
    
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('activation_key');
    
    bool activated = false;
    if (savedKey != null) {
      final expectedKey = HardwareInfo.generateActivationKey(mId);
      activated = savedKey == expectedKey;
    }

    state = state.copyWith(
      machineId: mId,
      isActivated: activated,
      isLoading: false,
    );
  }

  Future<bool> activate(String key) async {
    final expectedKey = HardwareInfo.generateActivationKey(state.machineId);
    if (key.trim() == expectedKey) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activation_key', key.trim());
      state = state.copyWith(isActivated: true);
      return true;
    }
    return false;
  }
}

final licenseProvider = NotifierProvider<LicenseNotifier, LicenseState>(() {
  return LicenseNotifier();
});
