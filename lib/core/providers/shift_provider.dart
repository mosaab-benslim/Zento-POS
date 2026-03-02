// lib/core/providers/shift_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift_model.dart';
import '../repositories/shift_repository.dart';
import '../../main.dart'; // To access appSettingsRepositoryProvider
import '../services/backup_service.dart';
import 'auth_provider.dart';

class ShiftState {
  final ShiftModel? activeShift;
  final ShiftModel? globalShift; // ✅ For Admin Dashboard monitoring
  final bool isLoading;
  final String? error;

  ShiftState({this.activeShift, this.globalShift, this.isLoading = false, this.error});

  ShiftState copyWith({ShiftModel? activeShift, ShiftModel? globalShift, bool? isLoading, String? error, bool clearActiveShift = false}) {
    return ShiftState(
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      globalShift: clearActiveShift ? null : (globalShift ?? this.globalShift),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ShiftNotifier extends Notifier<ShiftState> {
  Completer<void>? _syncCompleter;

  /// ✅ New: Allow UI to wait for existing sync to finish
  Future<void> waitForSync() async {
    if (!state.isLoading) return;
    await _syncCompleter?.future;
  }

  @override
  ShiftState build() {
    // Auto-load active shift if user is logged in
    final authState = ref.watch(authProvider);
    if (authState.currentUser != null) {
      final userId = authState.currentUser!.id!;
      _syncCompleter = Completer<void>();
      Future.microtask(() => _loadActiveShift(userId));
      return ShiftState(isLoading: true);
    }
    
    return ShiftState();
  }

  Future<void> _loadActiveShift(int userId) async {
    // 🔥 Guard: Prevent multiple simultaneous loads
    if (state.isLoading && state.activeShift != null) {
      _syncCompleter?.complete();
      return;
    }
    
    if (_syncCompleter?.isCompleted ?? false) {
      _syncCompleter = Completer<void>();
    }

    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(shiftRepositoryProvider);
      
      // Load both local and global shifts
      final shiftFuture = repository.getActiveShift(userId);
      final globalFuture = repository.getGlobalActiveShift();
      
      final results = await Future.wait([shiftFuture, globalFuture]);
      
      state = state.copyWith(
        activeShift: results[0], 
        globalShift: results[1],
        isLoading: false, 
        error: null
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    } finally {
      if (!(_syncCompleter?.isCompleted ?? true)) {
        _syncCompleter?.complete();
      }
    }
  }

  Future<void> openShift(double openingCash) async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(shiftRepositoryProvider);
      final shift = await repository.openShift(userId: user.id!, openingCash: openingCash);
      state = state.copyWith(activeShift: shift, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> closeShift(double actualCash) async {
    if (state.activeShift == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(shiftRepositoryProvider);
      await repository.closeShift(shift: state.activeShift!, actualCash: actualCash);
      
      // ✅ TRIGGER AUTO-BACKUP IF ENABLED
      final settings = await ref.read(appSettingsRepositoryProvider).getSettings();
      if (settings != null && settings.enableAutoBackup && settings.autoBackupPath != null) {
        // Run in background without waiting to speed up UI
        BackupService.performAutoBackup(settings.autoBackupPath!).catchError((e) {
           print("Automatic Cloud Backup failed: $e");
        });
      }

      state = state.copyWith(isLoading: false, clearActiveShift: true);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
