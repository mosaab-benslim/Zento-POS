import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/expense_dao.dart';
import '../models/expense_model.dart';

abstract class ExpenseRepository {
  Future<void> saveExpense(Expense expense);
  Future<List<Expense>> getExpenses({DateTime? start, DateTime? end});
  Future<void> deleteExpense(int id);
  Future<double> getTotalExpenses({DateTime? start, DateTime? end});
}

class LocalExpenseRepository implements ExpenseRepository {
  final ExpenseDao _dao = ExpenseDao();

  @override
  Future<void> saveExpense(Expense expense) async {
    await _dao.insertExpense(expense);
  }

  @override
  Future<List<Expense>> getExpenses({DateTime? start, DateTime? end}) async {
    return await _dao.getAllExpenses(start: start, end: end);
  }

  @override
  Future<void> deleteExpense(int id) async {
    await _dao.deleteExpense(id);
  }

  @override
  Future<double> getTotalExpenses({DateTime? start, DateTime? end}) async {
    return await _dao.getTotalExpenses(start: start, end: end);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return LocalExpenseRepository();
});
