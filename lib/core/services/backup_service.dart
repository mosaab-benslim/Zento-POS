import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

class BackupService {
  static Future<String?> backupDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, 'pos_system_v2.db'));

      if (!await sourceFile.exists()) {
        throw Exception("Database file not found at ${sourceFile.path}");
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final defaultFileName = 'zento_pos_backup_$timestamp.db';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Database Backup',
        fileName: defaultFileName,
        type: FileType.any,
      );

      if (outputFile == null) return null; // User cancelled

      // Ensure .db extension if not added by OS
      if (!outputFile.toLowerCase().endsWith('.db')) {
        outputFile += '.db';
      }

      await sourceFile.copy(outputFile);
      return outputFile;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> restoreDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Backup File (.db)',
      );

      if (result == null || result.files.single.path == null) return false;

      final sourcePath = result.files.single.path!;
      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, 'pos_system_v2.db');

      // 1. Close the current database connection
      final db = await AppDatabase.instance.database;
      await db.close();

      // 2. Overwrite the database file
      await File(sourcePath).copy(targetPath);

      // 3. Re-initialization happens automatically next time AppDatabase.instance.database is accessed.
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// 📧 Professional Sharing (Share via Email/WhatsApp/etc)
  static Future<void> shareBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, 'pos_system_v2.db'));

      if (!await sourceFile.exists()) return;

      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await Share.shareXFiles(
        [XFile(sourceFile.path, name: 'zento_pos_backup_$timestamp.db')],
        subject: 'Zento POS Database Backup - $timestamp',
        text: 'Attached is the database backup for Zento POS.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// ☁️ Automatic Cloud/Local Syncing
  static Future<void> performAutoBackup(String targetDirectory) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, 'pos_system_v2.db'));

      if (!await sourceFile.exists()) return;

      // Ensure directory exists
      final dir = Directory(targetDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Best for OneDrive/Dropbox: Overwrite a fixed filename
      final targetPath = join(targetDirectory, 'zento_pos_cloud_sync.db');
      await sourceFile.copy(targetPath);
      
      // Also a timestamped history copy
      final timestamp = DateFormat('yyyyMMdd_HH').format(DateTime.now());
      final historyDir = Directory(join(targetDirectory, 'history'));
      if (!await historyDir.exists()) await historyDir.create(recursive: true);
      
      final historyPath = join(historyDir.path, 'backup_$timestamp.db');
      await sourceFile.copy(historyPath);
      
      print("✅ Auto-Backup completed to $targetDirectory");
    } catch (e) {
      print("Auto-Backup Error: $e");
    }
  }
}
