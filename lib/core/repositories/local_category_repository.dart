import 'package:zento_pos/core/repositories/category_repository.dart';
import 'package:zento_pos/core/database/category_dao.dart'; 
import 'package:zento_pos/core/models/category_model.dart';

class LocalCategoryRepository implements CategoryRepository {
  final CategoryDao _categoryDao;

  LocalCategoryRepository(this._categoryDao);

  @override
  Future<List<Category>> getAllCategories() async {
    return await _categoryDao.getAllCategories();
  }

  @override
  Future<int> saveCategory(Category category) async {
    return await _categoryDao.insertCategory(category);
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _categoryDao.updateCategory(category);
  }

  @override
  Future<void> deleteCategory(int id) async {
    await _categoryDao.deleteCategory(id);
  }
}
