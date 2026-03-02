import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import '../models/product_ingredient_model.dart';
import 'app_database.dart';

class ProductDao {
  final dbProvider = AppDatabase.instance;

  Future<int> insertProduct(Product product) async {
    final db = await dbProvider.database;
    return await db.transaction<int>((txn) async {
      int productId;
      
      // Use replace logic manually to ensure we get the ID and handle dependencies
      if (product.id != null) {
        // Update existing
        await txn.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
        productId = product.id!;
        
        // Remove existing addons to replace with new state
        await txn.delete(
          'product_addons',
          where: 'productId = ?',
          whereArgs: [productId],
        );
      } else {
        // Insert new
        productId = await txn.insert('products', product.toMap());
      }

      for (final addon in product.addons) {
        await txn.insert('product_addons', addon.toMap(productId));
      }
      return productId;
    });
  }

  // Get products filtered by Category ID (Fast lookup)
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final db = await dbProvider.database;
    
    // 1. Get Products
    final productMaps = await db.query(
      'products',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
    );

    if (productMaps.isEmpty) return [];

    // 2. Get Addons for these products
    // Optimization: Fetch all addons for these products
    final productIds = productMaps.map((e) => e['id'] as int).toList();
    final addonMaps = await db.query(
      'product_addons',
      where: 'productId IN (${List.filled(productIds.length, '?').join(',')})',
      whereArgs: productIds,
    );

    // 3. Group addons by Product ID
    final addonsByProduct = <int, List<ProductAddon>>{};
    for (final map in addonMaps) {
      final productId = map['productId'] as int;
      final addon = ProductAddon.fromMap(map);
      
      if (!addonsByProduct.containsKey(productId)) {
        addonsByProduct[productId] = [];
      }
      addonsByProduct[productId]!.add(addon);
    }

    // 4. Merge
    return productMaps.map((json) {
      final id = json['id'] as int;
      return Product.fromMap(json, addons: addonsByProduct[id] ?? []);
    }).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await dbProvider.database;
    
    // 1. Get All Products
    final productMaps = await db.query('products');
    if (productMaps.isEmpty) return [];

    // 2. Get All Addons
    final addonMaps = await db.query('product_addons');

    // 3. Group addons
    final addonsByProduct = <int, List<ProductAddon>>{};
    for (final map in addonMaps) {
      final productId = map['productId'] as int;
      final addon = ProductAddon.fromMap(map);
      
      if (!addonsByProduct.containsKey(productId)) {
        addonsByProduct[productId] = [];
      }
      addonsByProduct[productId]!.add(addon);
    }

    // 4. Merge
    return productMaps.map((json) {
      final id = json['id'] as int;
      return Product.fromMap(json, addons: addonsByProduct[id] ?? []);
    }).toList();
  }

  Future<void> deleteProduct(int id) async {
    final db = await dbProvider.database;
    await db.transaction((txn) async {
      await txn.delete('product_addons', where: 'productId = ?', whereArgs: [id]);
      await txn.delete('product_ingredients', where: 'productId = ?', whereArgs: [id]); // ✅ Fix orphan recipes
      await txn.delete('stock_history', where: 'productId = ?', whereArgs: [id]);
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ───────── INVENTORY MANAGEMENT ─────────

  Future<int> adjustStock(int productId, int adjustment, String reason) async {
    final db = await dbProvider.database;
    return await db.transaction((txn) async {
      // 1. Get current stock
      final List<Map<String, dynamic>> result = await txn.query(
        'products',
        columns: ['stockQuantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (result.isEmpty) throw Exception("Product not found");

      final currentStock = result.first['stockQuantity'] as int;
      final newStock = currentStock + adjustment;

      // 2. Update stock
      await txn.update(
        'products',
        {'stockQuantity': newStock},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // 3. Log history
      await txn.insert('stock_history', {
        'productId': productId,
        'changeAmount': adjustment,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      return newStock;
    });
  }

  // ───────── RECIPE MANAGEMENT ─────────

  Future<List<ProductIngredient>> getRecipe(int productId) async {
    final db = await dbProvider.database;
    final result = await db.rawQuery('''
      SELECT pi.*, i.name as ingredientName, i.unit as ingredientUnit
      FROM product_ingredients pi
      JOIN ingredients i ON pi.ingredientId = i.id
      WHERE pi.productId = ?
    ''', [productId]);
    
    return result.map((e) => ProductIngredient.fromMap(e)).toList();
  }

  Future<void> updateRecipe(int productId, List<ProductIngredient> ingredients) async {
    final db = await dbProvider.database;
    await db.transaction((txn) async {
      // 1. Delete existing recipe
      await txn.delete('product_ingredients', where: 'productId = ?', whereArgs: [productId]);
      
      // 2. Insert new recipe items
      for (final ing in ingredients) {
        await txn.insert('product_ingredients', {
          'productId': productId, // Ensure correct ID
          'ingredientId': ing.ingredientId,
          'quantityNeeded': ing.quantityNeeded,
          'ingredientUnit': ing.ingredientUnit,
        });
      }
    });
  }
}
