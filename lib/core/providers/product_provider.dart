import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/core/utils/result.dart'; // Ensure Result is imported
import 'package:zento_pos/main.dart'; // Access productRepositoryProvider

class ProductNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    loadProducts();
    return [];
  }

  Future<void> loadProducts() async {
    try {
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getAllProducts();
      state = products;
    } catch (e) {
      state = [];
    }
  }

  Future<Result<int>> addProduct(Product product) async {
    final repo = ref.read(productRepositoryProvider);
    final result = await repo.saveProduct(product);
    
    if (result.isSuccess) {
      await loadProducts();
      return Result.success(result.value);
    } else {
      return Result.failure(result.error);
    }
  }

  Future<Result<int>> editProduct(Product product) async {
    final repo = ref.read(productRepositoryProvider);
    final result = await repo.saveProduct(product);
    
    if (result.isSuccess) {
      await loadProducts();
      return Result.success(result.value);
    } else {
      return Result.failure(result.error);
    }
  }

  Future<Result<void>> toggleStatus(int? id) async {
    if (id == null) return Result.failure("Invalid ID");
    final product = state.firstWhere((p) => p.id == id);
    final updated = product.copyWith(isEnabled: !product.isEnabled);
    final repo = ref.read(productRepositoryProvider);
    
    final result = await repo.saveProduct(updated);
    if (result.isSuccess) {
      await loadProducts();
      return Result.success(null);
    } else {
       return Result.failure(result.error);
    }
  }

  Future<Result<void>> deleteProduct(int? id) async {
    if (id == null) return Result.failure("Invalid ID");
    final repo = ref.read(productRepositoryProvider);
    final result = await repo.deleteProduct(id);
    if (result.isSuccess) {
      await loadProducts();
      return Result.success(null);
    } else {
      return Result.failure(result.error);
    }
  }
}

final productProvider = NotifierProvider<ProductNotifier, List<Product>>(ProductNotifier.new);

// ✅ Performance Optimization: Filter products by category efficiently
final categoryProductsProvider = Provider.family<List<Product>, int?>((ref, categoryId) {
  final allProducts = ref.watch(productProvider);
  if (categoryId == null) return [];
  return allProducts.where((p) => p.categoryId == categoryId && p.isEnabled).toList();
});
