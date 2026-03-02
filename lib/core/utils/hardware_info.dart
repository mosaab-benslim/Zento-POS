import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class HardwareInfo {
  static Future<String> getMachineId() async {
    try {
      // 1. Get Motherboard Serial
      final mbResult = await Process.run('powershell', ['-Command', 'gwmi -Class Win32_BaseBoard | Select-Object -ExpandProperty SerialNumber']);
      final mbSerial = mbResult.stdout.toString().trim();

      // 2. Get CPU ID
      final cpuResult = await Process.run('wmic', ['cpu', 'get', 'processorid']);
      final cpuId = cpuResult.stdout.toString().replaceAll('ProcessorId', '').trim();

      // 3. Combine and Hash
      if (mbSerial.isEmpty && cpuId.isEmpty) {
        return "UNKNOWN_DEVICE_${Platform.localHostname}";
      }

      final rawId = "SOLID_POS_${mbSerial}_${cpuId}";
      final bytes = utf8.encode(rawId);
      final hash = sha256.convert(bytes);
      
      return hash.toString().substring(0, 16).toUpperCase(); // 16-char unique Machine ID
    } catch (e) {
      return "ERROR_FETCHING_ID_${Platform.localHostname}";
    }
  }

  static String generateActivationKey(String machineId) {
    // This logic should ideally be kept SECRET or on a server
    // For now, we use a Salted Hash approach
    const salt = "SOLID_POS_MASTER_KEY_2026";
    final bytes = utf8.encode(machineId + salt);
    final hash = sha256.convert(bytes);
    
    // We take a different slice for the key
    final fullHash = hash.toString().toUpperCase();
    return "${fullHash.substring(4, 8)}-${fullHash.substring(12, 16)}-${fullHash.substring(20, 24)}-${fullHash.substring(28, 32)}";
  }
}
