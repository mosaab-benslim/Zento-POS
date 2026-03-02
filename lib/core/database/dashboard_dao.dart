import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class DashboardDao {
  final dbProvider = AppDatabase.instance;

  Future<double> getDailyRevenue(DateTime date) async {
    final db = await dbProvider.database;
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      'SELECT SUM(totalAmount) as total FROM orders WHERE timestamp BETWEEN ? AND ? AND status = 0',
      [start, end],
    );

    return (result.first['total'] as num? ?? 0.0).toDouble();
  }

  Future<double> getDailyProfit(DateTime date) async {
    final db = await dbProvider.database;
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;

    // Profit = (Price - Cost) * Quantity
    // We need to join orders -> order_items -> products (to get cost at time of sale? No, order_items has priceAtTime, but maybe not costAtTime. 
    // Ideally order_items should have stored cost. 
    // For now, let's use the current cost from products table as a proxy, or check if we store cost in order_items.
    // Checking app_database.dart... order_items has priceAtTime, but not cost. 
    // We will join with products table to get current cost. This is an approximation if cost changed, but sufficient for now.
    
    final result = await db.rawQuery('''
      SELECT SUM((oi.priceAtTime - p.cost) * oi.quantity) as profit
      FROM order_items oi
      INNER JOIN orders o ON oi.orderId = o.id
      INNER JOIN products p ON oi.productId = p.id
      WHERE o.timestamp BETWEEN ? AND ? AND o.status = 0
    ''', [start, end]);

    return (result.first['profit'] as num? ?? 0.0).toDouble();
  }

  Future<Map<int, double>> getMonthlyRevenue(int month, int year) async {
    final db = await dbProvider.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    // Handle December properly
    final end = (month == 12) 
        ? DateTime(year + 1, 1, 1).subtract(const Duration(milliseconds: 1)).millisecondsSinceEpoch
        : DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1)).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT strftime('%d', datetime(timestamp / 1000, 'unixepoch')) as day, SUM(totalAmount) as total
      FROM orders
      WHERE timestamp BETWEEN ? AND ? AND status = 0
      GROUP BY day
    ''', [start, end]);

    final Map<int, double> dailyRevenue = {};
    for (var row in result) {
      final day = int.parse(row['day'] as String);
      final total = (row['total'] as num).toDouble();
      dailyRevenue[day] = total;
    }
    return dailyRevenue;
  }

  Future<List<Map<String, dynamic>>> getLowStockItems(int limit) async {
    final db = await dbProvider.database;
    
    // Get low stock products and ingredients
    // Combine them? Or just products for now. Let's do products.
    // "alertLevel" is in products table.
    
    final result = await db.query(
      'products',
      where: 'trackStock = 1 AND stockQuantity <= alertLevel',
      orderBy: 'stockQuantity ASC',
      limit: limit,
    );

    return result;
  }

  Future<double> getTodayCashDifference(DateTime date) async {
    final db = await dbProvider.database;
    final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD

    // Sum of cashDifference for shifts closed today
    // endTime is stored as ISO8601 string (e.g. "2023-10-27T10:00:00.000")
    final result = await db.rawQuery(
      "SELECT SUM(cashDifference) as diff FROM shifts WHERE status = 'CLOSED' AND date(endTime) = ?",
      [dateString],
    );

    return (result.first['diff'] as num? ?? 0.0).toDouble();
  }
}
