import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/models/ingredient_model.dart';
import 'package:zento_pos/core/models/product_ingredient_model.dart';
import 'package:zento_pos/core/utils/result.dart';
import 'package:zento_pos/main.dart'; // Access ingredientRepositoryProvider

class IngredientNotifier extends AsyncNotifier<List<Ingredient>> {
  @override
  Future<List<Ingredient>> build() async {
    return _loadIngredients();
  }

  Future<List<Ingredient>> _loadIngredients() async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.getAllIngredients();
    if (result.isSuccess) {
      return result.value;
    } else {
      throw Exception(result.error);
    }
  }

  Future<Result<int>> saveIngredient(Ingredient ingredient) async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.saveIngredient(ingredient);
    if (result.isSuccess) {
      ref.invalidateSelf();
      return Result.success(result.value);
    }
    return Result.failure(result.error);
  }

  Future<Result<void>> deleteIngredient(int id) async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.deleteIngredient(id);
    if (result.isSuccess) {
      ref.invalidateSelf();
      return Result.success(null);
    }
    return Result.failure(result.error);
  }

  Future<Result<double>> adjustStock(int id, double amount, String reason) async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.adjustStock(id, amount, reason);
    if (result.isSuccess) {
      ref.invalidateSelf();
      return Result.success(result.value);
    }
    return Result.failure(result.error);
  }

  // Recipes
  Future<List<ProductIngredient>> getRecipe(int productId) async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.getRecipeForProduct(productId);
    return result.isSuccess ? result.value : [];
  }

  Future<Result<void>> saveRecipe(int productId, List<ProductIngredient> ingredients) async {
    final repo = ref.read(ingredientRepositoryProvider);
    final result = await repo.saveRecipe(productId, ingredients);
    if (result.isSuccess) {
      // Potentially invalidate other providers if they depend on recipes
      return Result.success(null);
    }
    return Result.failure(result.error);
  }

  Future<List<String>> getIngredientUsage(int id) async {
    final repo = ref.read(ingredientRepositoryProvider);
    return await repo.getProductsUsingIngredient(id);
  }
}

final ingredientProvider = AsyncNotifierProvider<IngredientNotifier, List<Ingredient>>(IngredientNotifier.new);
