// lib/core/database/shift_dao.dart

import 'package:sqflite/sqflite.dart';
import '../models/shift_model.dart';
import 'app_database.dart';

class ShiftDao {
  final _dbProvider = AppDatabase.instance;

  Future<int> openShift(ShiftModel shift) async {
    final db = await _dbProvider.database;
    return await db.insert('shifts', shift.toMap());
  }

  Future<int> updateShift(ShiftModel shift) async {
    final db = await _dbProvider.database;
    return await db.update(
      'shifts',
      shift.toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<ShiftModel?> getActiveShift(int userId) async {
    final db = await _dbProvider.database;
    final maps = await db.rawQuery('''
      SELECT s.*, u.name as userName 
      FROM shifts s
      LEFT JOIN users u ON s.userId = u.id
      WHERE s.userId = ? AND s.status = ? COLLATE NOCASE
      ORDER BY s.startTime DESC
      LIMIT 1
    ''', [userId, 'OPEN']);

    if (maps.isEmpty) return null;
    return ShiftModel.fromMap(maps.first);
  }

  /// ✅ New: Force close any older 'OPEN' shifts for this user to prevent ghost sessions
  Future<void> closeOrphanShifts(int userId, {int? exceptId}) async {
    final db = await _dbProvider.database;
    await db.update(
      'shifts',
      {
        'status': 'CLOSED',
        'endTime': DateTime.now().toIso8601String(),
        'closingCash': 0.0, // Mark as zero if forced closed
      },
      where: exceptId != null 
        ? 'userId = ? AND status = ? AND id != ?' 
        : 'userId = ? AND status = ?',
      whereArgs: exceptId != null 
        ? [userId, 'OPEN', exceptId] 
        : [userId, 'OPEN'],
    );
  }

  /// ✅ New: Get ANY open shift in the system (for Admin Dashboard)
  Future<ShiftModel?> getGlobalActiveShift() async {
    final db = await _dbProvider.database;
    final maps = await db.rawQuery('''
      SELECT s.*, u.name as userName 
      FROM shifts s
      LEFT JOIN users u ON s.userId = u.id
      WHERE s.status = ? COLLATE NOCASE
      ORDER BY s.startTime DESC
      LIMIT 1
    ''', ['OPEN']);

    if (maps.isEmpty) return null;
    return ShiftModel.fromMap(maps.first);
  }

  Future<List<ShiftModel>> getAllShifts() async {
    final db = await _dbProvider.database;
    final maps = await db.query('shifts', orderBy: 'startTime DESC');
    return maps.map((m) => ShiftModel.fromMap(m)).toList();
  }

  Future<Map<String, int>> getShiftSalesSummary(int shiftId) async {
    final db = await _dbProvider.database;
    
    // totalSales
    final totalResult = await db.rawQuery(
      'SELECT CAST(SUM(totalAmount) AS INT) as total FROM orders WHERE shiftId = ? AND status = 0',
      [shiftId],
    );
    
    // cashSales (PaymentMethod.cash = 0)
    final cashResult = await db.rawQuery(
      'SELECT CAST(SUM(totalAmount) AS INT) as total FROM orders WHERE shiftId = ? AND paymentMethod = 0 AND status = 0',
      [shiftId],
    );

    // cardSales (PaymentMethod.card = 1)
    final cardResult = await db.rawQuery(
      'SELECT CAST(SUM(totalAmount) AS INT) as total FROM orders WHERE shiftId = ? AND paymentMethod = 1 AND status = 0',
      [shiftId],
    );

    // otherSales (PaymentMethod.payOnDelivery = 2)
    final otherResult = await db.rawQuery(
      'SELECT CAST(SUM(totalAmount) AS INT) as total FROM orders WHERE shiftId = ? AND paymentMethod = 2 AND status = 0',
      [shiftId],
    );

    // cashOut (Expenses paid from drawer)
    final cashOutResult = await db.rawQuery(
      'SELECT CAST(SUM(amount) AS INT) as total FROM expenses WHERE shiftId = ? AND wasPaidFromDrawer = 1',
      [shiftId],
    );

    return {
      'total': (totalResult.first['total'] as int?) ?? 0,
      'cash': (cashResult.first['total'] as int?) ?? 0,
      'card': (cardResult.first['total'] as int?) ?? 0,
      'other': (otherResult.first['total'] as int?) ?? 0,
      'cashOut': (cashOutResult.first['total'] as int?) ?? 0,
    };
  }
}
