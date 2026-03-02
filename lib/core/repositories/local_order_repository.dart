import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'order_repository.dart';
import '../database/order_dao.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../utils/result.dart';

class LocalOrderRepository implements OrderRepository {
  final OrderDao _orderDao;

  LocalOrderRepository(this._orderDao);

  @override
  Future<int> getNextQueueNumber() async {
    final db = await AppDatabase.instance.database;
    return await _orderDao.getNextQueueNumber(db);
  }

  @override
  Future<Result<OrderModel>> createOrder(OrderModel order, List<OrderItem> items) async {
    final db = await AppDatabase.instance.database;
    try {
      late OrderModel finalizedOrder;
      await db.transaction((txn) async {
        // ✅ Only get NEW queue number if it's 0 (New Order)
        // If > 0, we keep it (Resumed Order / Hold Order)
        final queueNum = order.queueNumber == 0 
            ? await _orderDao.getNextQueueNumber(txn)
            : order.queueNumber;

        finalizedOrder = order.copyWith(
          createdAt: DateTime.now().toUtc(),
          queueNumber: queueNum,
        );
        await _orderDao.saveOrder(txn, finalizedOrder, items);
      });
      return Result.success(finalizedOrder);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<List<OrderModel>> getAllOrders({DateTime? start, DateTime? end}) {
    return _orderDao.getAllOrders(start: start, end: end);
  }

  @override
  Future<List<OrderModel>> getPendingOrders() async {
    return await _orderDao.getPendingOrders();
  }

  @override
  Future<List<OrderItem>> getOrderItems(int orderId) async {
    return await _orderDao.getOrderItems(orderId);
  }

  @override
  Future<Result<void>> deleteOrder(int orderId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await _orderDao.deleteOrder(txn, orderId);
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<List<OrderModel>> getHistoricalOrders({DateTime? start, DateTime? end}) async {
    return await _orderDao.getHistoricalOrders(start: start, end: end);
  }

  @override
  Future<Result<void>> voidOrder(int orderId) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await _orderDao.voidOrder(txn, orderId);
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getSummaryStats({DateTime? start, DateTime? end}) async {
    return await _orderDao.getSummaryStats(start: start, end: end);
  }

  @override
  Future<List<Map<String, dynamic>>> getDailySales({DateTime? start, DateTime? end}) async {
    return await _orderDao.getDailySales(start: start, end: end);
  }

  @override
  Future<List<Map<String, dynamic>>> getTopProducts({DateTime? start, DateTime? end}) async {
    return await _orderDao.getTopProducts(start: start, end: end);
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryBreakdown({DateTime? start, DateTime? end}) async {
    return await _orderDao.getCategoryBreakdown(start: start, end: end);
  }

  @override
  Future<Result<void>> updateOrderStatus(int orderId, OrderStatus status) async {
    try {
      final db = await AppDatabase.instance.database;
      await _orderDao.updateOrderStatus(db, orderId, status);
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<void>> markKOTPrinted(int orderId) async {
    try {
      final db = await AppDatabase.instance.database;
      await _orderDao.markKOTPrinted(db, orderId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
}
