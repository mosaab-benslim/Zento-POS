import 'package:sqflite/sqflite.dart';
import 'package:zento_pos/core/models/category_model.dart';
import 'package:zento_pos/core/database/app_database.dart';

class CategoryDao {
  final dbProvider = AppDatabase.instance;

  Future<int> insertCategory(Category category) async {
    final db = await dbProvider.database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(Category category) async {
    final db = await dbProvider.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await dbProvider.database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Category>> getAllCategories() async {
    final db = await dbProvider.database;
    final result = await db.query('categories', orderBy: 'orderIndex ASC');
    return result.map((json) => Category.fromMap(json)).toList();
  }
}
