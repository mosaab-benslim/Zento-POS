import '../models/ingredient_model.dart';
import '../models/product_ingredient_model.dart';
import '../utils/result.dart';

abstract class IngredientRepository {
  Future<Result<List<Ingredient>>> getAllIngredients();
  Future<Result<int>> saveIngredient(Ingredient ingredient);
  Future<Result<void>> deleteIngredient(int id);
  Future<Result<double>> adjustStock(int ingredientId, double adjustment, String reason);
  
  Future<Result<void>> saveRecipe(int productId, List<ProductIngredient> ingredients);
  Future<Result<List<ProductIngredient>>> getRecipeForProduct(int productId);
  Future<List<String>> getProductsUsingIngredient(int ingredientId);
}
