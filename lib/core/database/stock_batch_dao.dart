import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zento_pos/core/database/app_database.dart';
import 'package:zento_pos/core/models/stock_batch_model.dart';
import 'package:zento_pos/core/models/stock_batch_item_model.dart';

class StockBatchDao {
  final AppDatabase _appDatabase = AppDatabase.instance;

  Future<int> createBatchWithItems(StockBatch batch, List<StockBatchItem> items) async {
    final db = await _appDatabase.database;
    
    return await db.transaction((txn) async {
      // 1. Insert Batch Header
      final batchId = await txn.insert('stock_batches', batch.toMap());

      // 2. Insert Items & Update Inventory
      for (var item in items) {
        // Create a copy with the correct batchId
        final itemToInsert = StockBatchItem(
          batchId: batchId,
          ingredientId: item.ingredientId,
          ingredientName: item.ingredientName,
          quantityReceived: item.quantityReceived,
          costPerUnit: item.costPerUnit,
          subtotal: item.subtotal,
          expiryDate: item.expiryDate,
        );

        await txn.insert('stock_batch_items', itemToInsert.toMap());

        // 3. Update Ingredient Stock
        // Get current stock first (optional, but good for logs if we were logging detailed history per ingredient)
        
        // Simple update: currentStock = currentStock + quantity
        // Also update costPerUnit? Weighted average? 
        // For now, let's update the cost to the *latest* cost to keep it simple, or keep old if user wants.
        // Let's standard update cost to the new cost.
        await txn.rawUpdate('''
          UPDATE ingredients 
          SET currentStock = currentStock + ?, costPerUnit = ?
          WHERE id = ?
        ''', [item.quantityReceived, item.costPerUnit, item.ingredientId]);

        // ✅ LOG HISTORY
        await txn.insert('ingredient_stock_history', {
          'ingredientId': item.ingredientId,
          'changeAmount': item.quantityReceived,
          'reason': 'Stock Batch (Received)', 
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      return batchId;
    });
  }

  Future<List<StockBatch>> getAllBatches() async {
    final db = await _appDatabase.database;
    final result = await db.query('stock_batches', orderBy: 'receivedDate DESC');
    return result.map((e) => StockBatch.fromMap(e)).toList();
  }

  Future<List<StockBatchItem>> getBatchItems(int batchId) async {
    final db = await _appDatabase.database;
    final result = await db.query(
      'stock_batch_items',
      where: 'batchId = ?',
      whereArgs: [batchId],
    );
    return result.map((e) => StockBatchItem.fromMap(e)).toList();
  }
}
