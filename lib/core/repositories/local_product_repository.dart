import 'product_repository.dart';
import '../database/product_dao.dart'; // Import your ProductDao
import '../models/product_model.dart';
import '../models/product_ingredient_model.dart';
import '../utils/result.dart';

class LocalProductRepository implements ProductRepository {
  final ProductDao _productDao;

  // Inject the DAO via constructor
  LocalProductRepository(this._productDao);

  @override
  Future<List<Product>> getAllProducts() async {
    return await _productDao.getAllProducts();
  }

  @override
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    return await _productDao.getProductsByCategory(categoryId);
  }

  @override
  Future<Result<int>> saveProduct(Product product) async {
    try {
      final id = await _productDao.insertProduct(product);
      return Result.success(id);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<void>> deleteProduct(int id) async {
    try {
      await _productDao.deleteProduct(id);
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<int> adjustStock(int productId, int adjustment, String reason) async {
    return await _productDao.adjustStock(productId, adjustment, reason);
  }

  @override
  Future<List<ProductIngredient>> getRecipe(int productId) async {
    return await _productDao.getRecipe(productId);
  }

  @override
  Future<void> updateRecipe(int productId, List<ProductIngredient> ingredients) async {
    await _productDao.updateRecipe(productId, ingredients);
  }
}
