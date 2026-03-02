import 'dart:async';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/services/printer_service.dart';
import 'package:zento_pos/main.dart'; // To access appSettingsRepositoryProvider
import 'package:zento_pos/core/models/app_settings_model.dart';

class PrinterState {
  final List<PrinterDevice> devices;
  final bool isScanning;
  final bool isConnected;
  final String? selectedPrinterName;
  final String? error;

  PrinterState({
    this.devices = const [],
    this.isScanning = false,
    this.isConnected = false,
    this.selectedPrinterName,
    this.error,
  });

  PrinterState copyWith({
    List<PrinterDevice>? devices,
    bool? isScanning,
    bool? isConnected,
    String? selectedPrinterName,
    String? error,
  }) {
    return PrinterState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
      error: error,
    );
  }
}

class PrinterNotifier extends Notifier<PrinterState> {
  StreamSubscription? _scanSubscription;
  Timer? _reconnectTimer;

  @override
  PrinterState build() {
    _init();
    
    // ✅ Setup Auto-Reconnect Heartbeat
    _reconnectTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!state.isConnected && state.selectedPrinterName != null && !state.isScanning) {
        startScan();
      }
    });

    ref.onDispose(() {
      _scanSubscription?.cancel();
      _reconnectTimer?.cancel();
    });

    return PrinterState();
  }

  Future<void> _init() async {
    // 1. Load saved printer from settings
    final repo = ref.read(appSettingsRepositoryProvider);
    final settings = await repo.getSettings();
    final savedName = settings?.printerAddress;

    state = state.copyWith(selectedPrinterName: savedName);

    // 2. Start scanning immediately
    startScan();
  }

  void startScan() {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true, devices: []);
    _scanSubscription?.cancel();
    
    _scanSubscription = PrinterService.scanPrinters().listen((device) {
      final updatedDevices = List<PrinterDevice>.from(state.devices);
      if (!updatedPrintersContains(updatedDevices, device)) {
        updatedDevices.add(device);
        state = state.copyWith(devices: updatedDevices);

        // 🔄 Auto-Connect Logic
        if (state.selectedPrinterName != null && device.name == state.selectedPrinterName && !state.isConnected) {
          connect(device);
        }
      }
    }, onError: (err) {
      state = state.copyWith(isScanning: false, error: err.toString());
    }, onDone: () {
      state = state.copyWith(isScanning: false);
    });
  }

  bool updatedPrintersContains(List<PrinterDevice> list, PrinterDevice device) {
    return list.any((p) => p.name == device.name);
  }

  Future<bool> connect(PrinterDevice device) async {
    state = state.copyWith(isConnected: false);
    final success = await PrinterService.connect(device);
    
    if (success) {
      state = state.copyWith(
        isConnected: true, 
        selectedPrinterName: device.name,
        error: null,
      );
    } else {
      state = state.copyWith(isConnected: false, error: "Failed to connect to ${device.name}");
    }
    return success;
  }

  Future<void> setPrinterName(String? name) async {
    state = state.copyWith(selectedPrinterName: name);
  }

  void stopScan() {
    _scanSubscription?.cancel();
    state = state.copyWith(isScanning: false);
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterState>(PrinterNotifier.new);
