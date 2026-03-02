import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/shift_dao.dart';
import '../models/shift_model.dart';

class ShiftRepository {
  final _shiftDao = ShiftDao();

  Future<ShiftModel?> getActiveShift(int userId) async {
    return await _shiftDao.getActiveShift(userId);
  }

  /// ✅ New: Get global shift for dashboard monitoring
  Future<ShiftModel?> getGlobalActiveShift() async {
    return _shiftDao.getGlobalActiveShift();
  }

  Future<ShiftModel> openShift({
    required int userId,
    required double openingCash,
  }) async {
    // 🔥 Cleanup: Close any lingering 'OPEN' shifts for this user first
    await _shiftDao.closeOrphanShifts(userId);

    final shift = ShiftModel(
      userId: userId,
      startTime: DateTime.now(),
      openingCash: openingCash,
      status: ShiftStatus.open,
    );
    
    final id = await _shiftDao.openShift(shift);
    return shift.copyWith(id: id);
  }

  Future<ShiftModel> closeShift({
    required ShiftModel shift,
    required double actualCash, // Expecting double from text controller
  }) async {
    // 1. Get real-time sales summary from DB (Now in Cents)
    final summary = await _shiftDao.getShiftSalesSummary(shift.id!);
    
    final int totalSales = summary['total']!;
    final int cashSales = summary['cash']!;
    final int cardSales = summary['card']!;
    final int cashOut = summary['cashOut']!; // Money Out
    
    // 2. Calculate expected cash in CENTS
    // Opening cash is double in Model (major units), convert to cents
    final int openingCashCents = (shift.openingCash * 100).round();
    final int actualCashCents = (actualCash * 100).round();

    // Expected Cash = Opening Cash + Cash Sales - Money Out
    final int expectedCash = openingCashCents + cashSales - cashOut;
    final int difference = actualCashCents - expectedCash;

    final closedShift = shift.copyWith(
      endTime: DateTime.now(),
      closingCash: actualCash, 
      totalSales: totalSales / 100.0,
      totalCashSales: cashSales / 100.0,
      totalCardSales: cardSales / 100.0,
      expectedCash: expectedCash / 100.0,
      cashDifference: difference / 100.0,
      status: ShiftStatus.closed,
    );

    await _shiftDao.updateShift(closedShift);

    // 🔥 Cleanup: Also close any other lingering sessions for this user 
    // to ensure no "ghost" shifts reappear after relogin.
    await _shiftDao.closeOrphanShifts(shift.userId, exceptId: closedShift.id);

    return closedShift;
  }

  Future<List<ShiftModel>> getShiftHistory() async {
    return await _shiftDao.getAllShifts();
  }

  Future<Map<String, int>> getShiftSummary(int shiftId) async {
    return await _shiftDao.getShiftSalesSummary(shiftId);
  }
}

final shiftRepositoryProvider = Provider((ref) => ShiftRepository());
