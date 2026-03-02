import 'package:sqflite/sqflite.dart';
import '../models/order_item_model.dart';
import 'app_database.dart';

class OrderItemDao {
  final dbProvider = AppDatabase.instance;

  // Batch insert for performance (Atomic operation)
  Future<void> insertOrderItems(List<OrderItem> items) async {
    final db = await dbProvider.database;
    final batch = db.batch();

    for (var item in items) {
      batch.insert(
        'order_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // commit(noResult: true) is faster because we don't need the IDs back
    await batch.commit(noResult: true);
  }
}
