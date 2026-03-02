import '../models/order_model.dart'; 
import '../models/order_item_model.dart';
import '../utils/result.dart';

abstract class OrderRepository {
  /// Creates a new order along with its associated items.
  Future<Result<OrderModel>> createOrder(OrderModel order, List<OrderItem> items);

  /// Gets the next queue number for the current day.
  Future<int> getNextQueueNumber();

  /// Retrieves all existing orders.
  Future<List<OrderModel>> getAllOrders({DateTime? start, DateTime? end});

  /// Retrieves orders with pending status.
  Future<List<OrderModel>> getPendingOrders();

  /// Retrieves items for a specific order.
  Future<List<OrderItem>> getOrderItems(int orderId);

  /// Deletes an order (usually to resume or cancel it).
  Future<Result<void>> deleteOrder(int orderId);

  /// Retrieves orders for history (completed and voided).
  Future<List<OrderModel>> getHistoricalOrders({DateTime? start, DateTime? end});

  /// Marks an order as voided.
  Future<Result<void>> voidOrder(int orderId);

  /// Updates the status of an order (Preparing, Ready, etc.)
  Future<Result<void>> updateOrderStatus(int orderId, OrderStatus status);

  /// Updates the KOT printed timestamp
  Future<Result<void>> markKOTPrinted(int orderId);

  // --- ANALYTICS ---
  Future<Map<String, dynamic>> getSummaryStats({DateTime? start, DateTime? end});
  Future<List<Map<String, dynamic>>> getDailySales({DateTime? start, DateTime? end});
  Future<List<Map<String, dynamic>>> getTopProducts({DateTime? start, DateTime? end});
  Future<List<Map<String, dynamic>>> getCategoryBreakdown({DateTime? start, DateTime? end});
}
