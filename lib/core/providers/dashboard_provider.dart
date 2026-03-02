import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';

// AsyncNotifier to handle loading state automatically
class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    final repository = ref.read(dashboardRepositoryProvider);
    return repository.getDashboardStats();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(dashboardRepositoryProvider).getDashboardStats();
    });
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardStats>(DashboardNotifier.new);
