import '../models/product_model.dart'; // Import your Product model
import '../models/product_ingredient_model.dart';
import '../utils/result.dart';

abstract class ProductRepository {
  /// Retrieves all products.
  Future<List<Product>> getAllProducts();

  /// Retrieves products belonging to a specific category.
  Future<List<Product>> getProductsByCategory(int categoryId);

  /// Saves or updates a product.
  Future<Result<int>> saveProduct(Product product);

  /// Deletes a product.
  Future<Result<void>> deleteProduct(int id);
  Future<int> adjustStock(int productId, int adjustment, String reason);
  
  // Recipe methods
  Future<List<ProductIngredient>> getRecipe(int productId);
  Future<void> updateRecipe(int productId, List<ProductIngredient> ingredients);
}
