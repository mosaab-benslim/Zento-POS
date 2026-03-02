import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/main.dart'; // Access productRepositoryProvider
import '../database/dashboard_dao.dart';
import '../models/product_model.dart';
import 'product_repository.dart'; // Abstract class
import 'local_product_repository.dart'; // Concrete implementation

class DashboardStats {
  final double todayRevenue;
  final double todayProfit;
  final Map<int, double> monthlyRevenue;
  final List<Product> lowStockItems;
  final double cashDifference; // New field

  DashboardStats({
    required this.todayRevenue,
    required this.todayProfit,
    required this.monthlyRevenue,
    required this.lowStockItems,
    required this.cashDifference,
  });
}

class DashboardRepository {
  final _dao = DashboardDao();
  final ProductRepository _productRepo; 

  DashboardRepository(this._productRepo);

  Future<DashboardStats> getDashboardStats() async {
    final now = DateTime.now();

    // 1. Parallelize fetching for speed
    final revenueFuture = _dao.getDailyRevenue(now);
    final profitFuture = _dao.getDailyProfit(now);
    final monthlyFuture = _dao.getMonthlyRevenue(now.month, now.year);
    final lowStockFuture = _dao.getLowStockItems(5); // Top 5 low stock items
    final cashDiffFuture = _dao.getTodayCashDifference(now); // New query

    final results = await Future.wait([
      revenueFuture,
      profitFuture,
      monthlyFuture,
      lowStockFuture,
      cashDiffFuture,
    ]);

    // 2. Parse Low Stock items back to models
    // Since DAO returns Maps, we can map them back to Products easily if we trust the structure
    // Or we can use the ProductRepository if we want full hydration, but DAO is faster.
    // Let's assume DAO returns raw maps matching Product schema.
    final lowStockMaps = results[3] as List<Map<String, dynamic>>;
    final lowStockProducts = lowStockMaps.map((m) => Product.fromMap(m)).toList();

    return DashboardStats(
      todayRevenue: results[0] as double,
      todayProfit: results[1] as double,
      monthlyRevenue: results[2] as Map<int, double>,
      lowStockItems: lowStockProducts,
      cashDifference: results[4] as double,
    );
  }
}

final dashboardRepositoryProvider = Provider((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return DashboardRepository(productRepo);
});
