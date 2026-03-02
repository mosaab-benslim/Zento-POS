import 'package:sqflite/sqflite.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../utils/result.dart';
import 'app_database.dart';

class OrderDao {
  final dbProvider = AppDatabase.instance;

  Future<int> getNextQueueNumber(DatabaseExecutor db) async {
    final now = DateTime.now().toUtc();
    final startOfUtcDay = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    final result = await db.rawQuery(
      'SELECT MAX(queueNumber) as maxNum FROM orders WHERE timestamp >= ?',
      [startOfUtcDay]
    );
    
    final int maxNum = (result.first['maxNum'] as int?) ?? 0;
    return maxNum + 1;
  }

  Future<void> saveOrder(DatabaseExecutor db, OrderModel order, List<OrderItem> items) async {
    final orderId = await db.insert(
      'orders',
      order.toMap(),
    );

    for (var item in items) {
      final itemMap = item.copyWith(orderId: orderId).toMap();
      await db.insert('order_items', itemMap);
      await _deductStock(db, item.productId, item.quantity);
    }
  }

  Future<void> _deductStock(DatabaseExecutor db, int productId, int quantity) async {
    final recipeResults = await db.query(
      'product_ingredients',
      where: 'productId = ?',
      whereArgs: [productId],
    );

    if (recipeResults.isNotEmpty) {
      for (final row in recipeResults) {
        final int ingredientId = row['ingredientId'] as int;
        double qtyNeeded = (row['quantityNeeded'] as num).toDouble();
        final String? recipeUnit = row['ingredientUnit'] as String?; 
        
        final ingredientMaps = await db.query(
          'ingredients',
          columns: ['currentStock', 'unit'],
          where: 'id = ?',
          whereArgs: [ingredientId],
        );

        if (ingredientMaps.isNotEmpty) {
          final ingredient = ingredientMaps.first;
          final double currentStock = (ingredient['currentStock'] as num).toDouble();
          final String stockUnit = (ingredient['unit'] as String?) ?? 'kg';

          if (recipeUnit != null && recipeUnit != stockUnit) {
             if (stockUnit == 'kg' && recipeUnit == 'g') {
               qtyNeeded = qtyNeeded / 1000.0;
             } else if (stockUnit == 'L' && recipeUnit == 'ml') {
               qtyNeeded = qtyNeeded / 1000.0;
             }
          }

          final double totalDeduction = qtyNeeded * quantity;
          final double newStock = currentStock - totalDeduction;

          await db.update(
            'ingredients',
            {'currentStock': newStock},
            where: 'id = ?',
            whereArgs: [ingredientId],
          );

          // ✅ LOG HISTORY FOR INGREDIENT
          await db.insert('ingredient_stock_history', {
            'ingredientId': ingredientId,
            'changeAmount': -totalDeduction,
            'reason': 'Order Sale (Recipe)', 
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      return;
    }

    final result = await db.query(
      'products',
      columns: ['trackStock', 'stockQuantity'],
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (result.isNotEmpty) {
      final product = result.first;
      final trackStock = (product['trackStock'] as int) == 1;

      if (trackStock) {
        final currentStock = product['stockQuantity'] as int;
        final newStock = currentStock - quantity;

        await db.update(
          'products',
          {'stockQuantity': newStock},
          where: 'id = ?',
          whereArgs: [productId],
        );

        await db.insert('stock_history', {
          'productId': productId,
          'changeAmount': -quantity,
          'reason': 'Order Sale', 
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  Future<List<OrderModel>> getAllOrders({DateTime? start, DateTime? end, int limit = 50}) async {
    final db = await dbProvider.database;
    String where = '1=1'; 
    List<dynamic> args = [];
    
    if (start != null && end != null) {
      where += ' AND timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }
    
    final result = await db.query('orders', where: where, whereArgs: args, orderBy: 'timestamp DESC', limit: limit);
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  Future<List<OrderModel>> getHistoricalOrders({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String where = '1=1'; 
    List<dynamic> args = [];
    
    if (start != null && end != null) {
      where += ' AND timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }
    
    final result = await db.query('orders', where: where, whereArgs: args, orderBy: 'timestamp DESC');
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  Future<void> voidOrder(DatabaseExecutor db, int orderId) async {
    await db.update('orders', {'status': 2}, where: 'id = ?', whereArgs: [orderId]);
    final items = await getOrderItems(orderId, db: db);
    for (var item in items) {
       await _deductStock(db, item.productId, -item.quantity);
    }
  }

  Future<List<OrderModel>> getPendingOrders() async {
    final db = await dbProvider.database;
    final result = await db.query('orders', where: 'status = 1', orderBy: 'timestamp ASC');
    return result.map((json) => OrderModel.fromMap(json)).toList();
  }

  Future<void> deleteOrder(DatabaseExecutor db, int orderId) async {
    final items = await getOrderItems(orderId, db: db);
    for (var item in items) {
       await _deductStock(db, item.productId, -item.quantity);
    }
    await db.delete('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  Future<List<OrderItem>> getOrderItems(int orderId, {DatabaseExecutor? db}) async {
    final executor = db ?? await dbProvider.database;
    final result = await executor.query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    return result.map((json) => OrderItem.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getSummaryStats({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String whereClause = 'WHERE status = 0';
    List<dynamic> args = [];

    if (start != null && end != null) {
      whereClause = 'WHERE status = 0 AND timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as order_count,
        SUM(totalAmount) as total_revenue,
        AVG(totalAmount) as avg_order
      FROM orders
      $whereClause
    ''', args);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getDailySales({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String whereClause = 'WHERE status = 0';
    List<dynamic> args = [];

    if (start != null && end != null) {
      whereClause += ' AND timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    return await db.rawQuery('''
      SELECT 
        date(timestamp / 1000, 'unixepoch') as date_str,
        SUM(totalAmount) as revenue
      FROM orders
      $whereClause
      GROUP BY date_str
      ORDER BY date_str ASC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getTopProducts({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String whereClause = 'WHERE o.status = 0';
    List<dynamic> args = [];

    if (start != null && end != null) {
      whereClause += ' AND o.timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    return await db.rawQuery('''
      SELECT 
        oi.productName as name,
        SUM(oi.quantity) as qty
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      $whereClause
      GROUP BY oi.productName
      ORDER BY qty DESC
      LIMIT 10
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown({DateTime? start, DateTime? end}) async {
    final db = await dbProvider.database;
    String whereClause = 'WHERE o.status = 0';
    List<dynamic> args = [];

    if (start != null && end != null) {
      whereClause += ' AND o.timestamp BETWEEN ? AND ?';
      args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    return await db.rawQuery('''
      SELECT 
        c.name as category,
        SUM(oi.priceAtTime * oi.quantity) as revenue
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      JOIN products p ON oi.productId = p.id
      JOIN categories c ON p.categoryId = c.id
      $whereClause
      GROUP BY c.id
      ORDER BY revenue DESC
    ''', args);
  }

  Future<void> updateOrderStatus(DatabaseExecutor db, int orderId, OrderStatus status) async {
    await db.update(
      'orders', 
      {'status': status.index}, 
      where: 'id = ?', 
      whereArgs: [orderId]
    );
  }

  Future<void> markKOTPrinted(DatabaseExecutor db, int orderId) async {
    await db.update(
      'orders', 
      {'kot_printed_at': DateTime.now().millisecondsSinceEpoch}, 
      where: 'id = ?', 
      whereArgs: [orderId]
    );
  }
}
