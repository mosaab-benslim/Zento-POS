import '../database/ingredient_dao.dart';
import '../models/ingredient_model.dart';
import '../models/product_ingredient_model.dart';
import '../utils/result.dart';
import 'ingredient_repository.dart';

class LocalIngredientRepository implements IngredientRepository {
  final IngredientDao dao;

  LocalIngredientRepository(this.dao);

  @override
  Future<Result<List<Ingredient>>> getAllIngredients() async {
    try {
      final ingredients = await dao.getAllIngredients();
      return Result.success(ingredients);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<int>> saveIngredient(Ingredient ingredient) async {
    try {
      final id = await dao.insertIngredient(ingredient);
      return Result.success(id);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<void>> deleteIngredient(int id) async {
    try {
      await dao.deleteIngredient(id);
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<double>> adjustStock(int ingredientId, double adjustment, String reason) async {
    try {
      final newStock = await dao.adjustStock(ingredientId, adjustment, reason);
      return Result.success(newStock);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<void>> saveRecipe(int productId, List<ProductIngredient> ingredients) async {
    try {
      await dao.saveRecipe(productId, ingredients);
      return Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<Result<List<ProductIngredient>>> getRecipeForProduct(int productId) async {
    try {
      final recipe = await dao.getRecipeForProduct(productId);
      return Result.success(recipe);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  @override
  Future<List<String>> getProductsUsingIngredient(int ingredientId) async {
    return await dao.getProductsUsingIngredient(ingredientId);
  }
}
