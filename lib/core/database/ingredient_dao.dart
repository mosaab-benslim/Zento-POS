import 'package:sqflite/sqflite.dart';
import '../models/ingredient_model.dart';
import '../models/product_ingredient_model.dart';
import 'app_database.dart';

class IngredientDao {
  final dbProvider = AppDatabase.instance;

  // ───────── INGREDIENT CRUD ─────────

  Future<int> insertIngredient(Ingredient ingredient) async {
    final db = await dbProvider.database;
    if (ingredient.id != null) {
      await db.update(
        'ingredients',
        ingredient.toMap(),
        where: 'id = ?',
        whereArgs: [ingredient.id],
      );
      return ingredient.id!;
    } else {
      return await db.insert('ingredients', ingredient.toMap());
    }
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final db = await dbProvider.database;
    final maps = await db.query('ingredients', orderBy: 'name ASC');
    return maps.map((m) => Ingredient.fromMap(m)).toList();
  }

  Future<void> deleteIngredient(int id) async {
    final db = await dbProvider.database;
    await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> adjustStock(int ingredientId, double adjustment, String reason) async {
    final db = await dbProvider.database;
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> result = await txn.query(
        'ingredients',
        columns: ['currentStock'],
        where: 'id = ?',
        whereArgs: [ingredientId],
      );

      if (result.isEmpty) throw Exception("Ingredient not found");

      final currentStock = (result.first['currentStock'] as num).toDouble();
      final newStock = currentStock + adjustment;

      await txn.update(
        'ingredients',
        {'currentStock': newStock},
        where: 'id = ?',
        whereArgs: [ingredientId],
      );

      // ✅ LOG HISTORY
      await txn.insert('ingredient_stock_history', {
        'ingredientId': ingredientId,
        'changeAmount': adjustment,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      return newStock;
    });
  }

  // ───────── RECIPE MANAGEMENT ─────────

  Future<void> saveRecipe(int productId, List<ProductIngredient> ingredients) async {
    final db = await dbProvider.database;
    await db.transaction((txn) async {
      // 1. Delete existing recipe
      await txn.delete(
        'product_ingredients',
        where: 'productId = ?',
        whereArgs: [productId],
      );

      // 2. Insert new ingredients
      for (final pi in ingredients) {
        await txn.insert('product_ingredients', pi.copyWith(productId: productId).toMap());
      }
    });
  }

  Future<List<ProductIngredient>> getRecipeForProduct(int productId) async {
    final db = await dbProvider.database;
    final results = await db.rawQuery('''
      SELECT pi.*, i.name as ingredientName, i.unit as ingredientUnit
      FROM product_ingredients pi
      JOIN ingredients i ON pi.ingredientId = i.id
      WHERE pi.productId = ?
    ''', [productId]);

    return results.map((m) => ProductIngredient.fromMap(m)).toList();
  }

  Future<List<String>> getProductsUsingIngredient(int ingredientId) async {
    final db = await dbProvider.database;
    final results = await db.rawQuery('''
      SELECT p.name
      FROM product_ingredients pi
      JOIN products p ON pi.productId = p.id
      WHERE pi.ingredientId = ?
    ''', [ingredientId]);

    return results.map((m) => m['name'] as String).toList();
  }
}



