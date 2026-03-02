import 'package:zento_pos/core/models/category_model.dart'; 

abstract class CategoryRepository {
  /// Retrieves all categories.
  Future<List<Category>> getAllCategories();

  /// Saves or updates a category. Returns the ID of the saved category.
  Future<int> saveCategory(Category category);

  /// Updates an existing category.
  Future<void> updateCategory(Category category);

  /// Deletes a category by ID.
  Future<void> deleteCategory(int id);
}
