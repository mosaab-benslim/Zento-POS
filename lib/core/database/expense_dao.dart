import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/expense_model.dart';

class ExpenseDao {
  final dbProvider = AppDatabase.instance;

  Future<int> insertExpense(Expense expense) async {
    final db = await dbProvider.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String? where;
    List<dynamic>? args;

    if (start != null && end != null) {
      where = 'timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    final result = await db.query('expenses', where: where, whereArgs: args, orderBy: 'timestamp DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<void> deleteExpense(int id) async {
    final db = await dbProvider.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalExpenses({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String whereClause = '';
    List<dynamic> args = [];

    if (start != null && end != null) {
      whereClause = 'WHERE timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    final result = await db.rawQuery('SELECT SUM(amount) as total FROM expenses $whereClause', args);
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  Future<double> getShiftExpenseTotal(int shiftId) async {
    final db = await dbProvider.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE shiftId = ? AND wasPaidFromDrawer = 1',
      [shiftId],
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }
}
