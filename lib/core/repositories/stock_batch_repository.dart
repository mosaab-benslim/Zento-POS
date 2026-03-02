import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/stock_batch_dao.dart';
import '../models/stock_batch_model.dart';
import '../models/stock_batch_item_model.dart';

abstract class StockBatchRepository {
  Future<int> receiveStock(StockBatch batch, List<StockBatchItem> items);
  Future<List<StockBatch>> fetchAllBatches();
  Future<List<StockBatchItem>> fetchBatchItems(int batchId);
}

class LocalStockBatchRepository implements StockBatchRepository {
  final StockBatchDao _dao = StockBatchDao();

  @override
  Future<int> receiveStock(StockBatch batch, List<StockBatchItem> items) async {
    return await _dao.createBatchWithItems(batch, items);
  }

  @override
  Future<List<StockBatch>> fetchAllBatches() async {
    return await _dao.getAllBatches();
  }

  @override
  Future<List<StockBatchItem>> fetchBatchItems(int batchId) async {
    return await _dao.getBatchItems(batchId);
  }
}

final stockBatchRepositoryProvider = Provider<StockBatchRepository>((ref) {
  return LocalStockBatchRepository();
});
