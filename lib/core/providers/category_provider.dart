import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/product_provider.dart';
import 'package:zento_pos/main.dart'; 
import 'package:zento_pos/core/models/category_model.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/core/models/ingredient_model.dart';
import 'package:zento_pos/core/models/product_ingredient_model.dart';
class CategoryNotifier extends Notifier<List<Category>> {
  @override
  List<Category> build() {
    loadCategories();
    return [];
  }

  Future<void> loadCategories() async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final categories = await repo.getAllCategories();
      state = categories;
    } catch (e) {
      state = [];
    }
  }

  Future<void> seedSampleData() async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final productRepo = ref.read(productRepositoryProvider);
    final ingredientRepo = ref.read(ingredientRepositoryProvider);

    print('🚀 Starting Massive Seeding (French Edition)...');

    // 1. Create Ingredients First
    final ingredientsData = [
      {'name': 'Pain Burger', 'unit': 'pcs', 'cost': 0.50},
      {'name': 'Steak Haché', 'unit': 'pcs', 'cost': 1.20},
      {'name': 'Fromage Cheddar', 'unit': 'tranches', 'cost': 0.30},
      {'name': 'Salade', 'unit': 'grammes', 'cost': 0.05},
      {'name': 'Tomate', 'unit': 'tranches', 'cost': 0.10},
      {'name': 'Sauce Burger', 'unit': 'ml', 'cost': 0.20},
      {'name': 'Frites', 'unit': 'grammes', 'cost': 0.50},
      {'name': 'Pâte à Pizza', 'unit': 'pcs', 'cost': 1.00},
      {'name': 'Sauce Tomate Pizza', 'unit': 'ml', 'cost': 0.40},
      {'name': 'Mozzarella', 'unit': 'grammes', 'cost': 1.50},
      {'name': 'Poulet', 'unit': 'grammes', 'cost': 2.00},
      {'name': 'Tortilla Tacos', 'unit': 'pcs', 'cost': 0.40},
      {'name': 'Sauce Fromagère', 'unit': 'ml', 'cost': 0.60},
      {'name': 'Baguette', 'unit': 'pcs', 'cost': 0.80},
      {'name': 'Jambon', 'unit': 'tranches', 'cost': 0.50},
      {'name': 'Beurre', 'unit': 'grammes', 'cost': 0.10},
      {'name': 'Pâtes Penne', 'unit': 'grammes', 'cost': 0.60},
      {'name': 'Crème Fraîche', 'unit': 'ml', 'cost': 0.80},
      {'name': 'Lardons', 'unit': 'grammes', 'cost': 1.00},
      {'name': 'Sirop Cola', 'unit': 'ml', 'cost': 0.30},
      {'name': 'Eau Gazeuse', 'unit': 'ml', 'cost': 0.20},
      {'name': 'Café Grains', 'unit': 'grammes', 'cost': 0.40},
      {'name': 'Lait', 'unit': 'ml', 'cost': 0.30},
      {'name': 'Sucre', 'unit': 'grammes', 'cost': 0.05},
      {'name': 'Fondant Chocolat', 'unit': 'pcs', 'cost': 1.50},
    ];

    Map<String, int> ingredientIds = {};
    for (var ing in ingredientsData) {
      final ingredient = Ingredient(
        name: ing['name'] as String,
        unit: ing['unit'] as String,
        costPerUnit: ing['cost'] as double,
        currentStock: 1000,
      );
      final result = await ingredientRepo.saveIngredient(ingredient);
      if (result.isSuccess) {
        ingredientIds[ingredient.name] = result.value;
      }
    }

    int getIngId(String name) => ingredientIds[name] ?? 0;

    // 2. Categories & Products
    final categoriesData = [
      {'name': 'Burgers', 'color': 0xFFE74C3C},
      {'name': 'Boissons', 'color': 0xFF3498DB},
      {'name': 'Sandwichs', 'color': 0xFFF1C40F},
      {'name': 'Pizzas', 'color': 0xFFE67E22},
      {'name': 'Salades', 'color': 0xFF2ECC71},
      {'name': 'Desserts', 'color': 0xFF9B59B6},
      {'name': 'Tacos', 'color': 0xFFD35400},
      {'name': 'Pâtes', 'color': 0xFFFFC107},
      {'name': 'Accompagnements', 'color': 0xFF795548},
      {'name': 'Cafés', 'color': 0xFF607D8B},
    ];

    final productsData = {
      'Burgers': [
        {
          'name': 'Cheeseburger',
          'price': 850,
          'recipe': [
            {'name': 'Pain Burger', 'qty': 1.0},
            {'name': 'Steak Haché', 'qty': 1.0},
            {'name': 'Fromage Cheddar', 'qty': 1.0},
            {'name': 'Sauce Burger', 'qty': 20.0},
          ]
        },
        {
          'name': 'Double Cheese',
          'price': 1100,
          'recipe': [
            {'name': 'Pain Burger', 'qty': 1.0},
            {'name': 'Steak Haché', 'qty': 2.0},
            {'name': 'Fromage Cheddar', 'qty': 2.0},
            {'name': 'Sauce Burger', 'qty': 30.0},
          ]
        },
        {
          'name': 'Burger Poulet',
          'price': 900,
          'recipe': [
            {'name': 'Pain Burger', 'qty': 1.0},
            {'name': 'Poulet', 'qty': 150.0},
            {'name': 'Salade', 'qty': 20.0},
            {'name': 'Sauce Burger', 'qty': 20.0},
          ]
        }
      ],
      'Boissons': [
        {
          'name': 'Coca-Cola 33cl',
          'price': 250,
          'recipe': []
        },
        {
          'name': 'Ice Tea 33cl',
          'price': 250,
          'recipe': []
        },
        {
          'name': 'Eau Minérale 50cl',
          'price': 200,
          'recipe': []
        }
      ],
      'Sandwichs': [
        {
          'name': 'Sandwich Poulet',
          'price': 650,
          'recipe': [
            {'name': 'Baguette', 'qty': 1.0},
            {'name': 'Poulet', 'qty': 100.0},
            {'name': 'Salade', 'qty': 30.0},
            {'name': 'Tomate', 'qty': 3.0},
          ]
        },
        {
          'name': 'Jambon Beurre',
          'price': 500,
          'recipe': [
            {'name': 'Baguette', 'qty': 1.0},
            {'name': 'Jambon', 'qty': 2.0},
            {'name': 'Beurre', 'qty': 15.0},
          ]
        }
      ],
      'Pizzas': [
        {
          'name': 'Margherita',
          'price': 1100,
          'recipe': [
            {'name': 'Pâte à Pizza', 'qty': 1.0},
            {'name': 'Sauce Tomate Pizza', 'qty': 100.0},
            {'name': 'Mozzarella', 'qty': 150.0},
          ]
        },
        {
          'name': 'Reine',
          'price': 1300,
          'recipe': [
            {'name': 'Pâte à Pizza', 'qty': 1.0},
            {'name': 'Sauce Tomate Pizza', 'qty': 100.0},
            {'name': 'Mozzarella', 'qty': 150.0},
            {'name': 'Jambon', 'qty': 4.0},
          ]
        }
      ],
      'Salades': [
        {
          'name': 'Salade César',
          'price': 1200,
          'recipe': [
            {'name': 'Salade', 'qty': 150.0},
            {'name': 'Poulet', 'qty': 100.0},
            {'name': 'Tomate', 'qty': 4.0},
          ]
        },
        {
          'name': 'Salade Verte',
          'price': 500,
          'recipe': [
            {'name': 'Salade', 'qty': 100.0},
            {'name': 'Tomate', 'qty': 2.0},
          ]
        }
      ],
      'Desserts': [
        {
          'name': 'Tiramisu',
          'price': 450,
          'recipe': [] 
        },
        {
          'name': 'Fondant au Chocolat',
          'price': 500,
          'recipe': [
            {'name': 'Fondant Chocolat', 'qty': 1.0},
          ]
        }
      ],
      'Tacos': [
        {
          'name': 'Tacos 1 Viande',
          'price': 800,
          'recipe': [
            {'name': 'Tortilla Tacos', 'qty': 1.0},
            {'name': 'Poulet', 'qty': 100.0},
            {'name': 'Frites', 'qty': 150.0},
            {'name': 'Sauce Fromagère', 'qty': 50.0},
          ]
        },
        {
          'name': 'Tacos 2 Viandes',
          'price': 1050,
          'recipe': [
            {'name': 'Tortilla Tacos', 'qty': 1.0},
            {'name': 'Poulet', 'qty': 100.0},
            {'name': 'Steak Haché', 'qty': 1.0},
            {'name': 'Frites', 'qty': 150.0},
            {'name': 'Sauce Fromagère', 'qty': 80.0},
          ]
        }
      ],
      'Pâtes': [
        {
          'name': 'Pâtes Carbonara',
          'price': 1250,
          'recipe': [
            {'name': 'Pâtes Penne', 'qty': 200.0},
            {'name': 'Crème Fraîche', 'qty': 100.0},
            {'name': 'Lardons', 'qty': 100.0},
          ]
        },
        {
          'name': 'Pâtes Bolognaise',
          'price': 1250,
          'recipe': [
            {'name': 'Pâtes Penne', 'qty': 200.0},
            {'name': 'Sauce Tomate Pizza', 'qty': 100.0},
            {'name': 'Steak Haché', 'qty': 1.0},
          ]
        }
      ],
      'Accompagnements': [
        {
          'name': 'Petite Frite',
          'price': 300,
          'recipe': [
            {'name': 'Frites', 'qty': 150.0},
          ]
        },
        {
          'name': 'Grande Frite',
          'price': 450,
          'recipe': [
            {'name': 'Frites', 'qty': 300.0},
          ]
        }
      ],
      'Cafés': [
        {
          'name': 'Espresso',
          'price': 180,
          'recipe': [
            {'name': 'Café Grains', 'qty': 7.0},
          ]
        },
        {
          'name': 'Café Crème',
          'price': 350,
          'recipe': [
            {'name': 'Café Grains', 'qty': 7.0},
            {'name': 'Lait', 'qty': 100.0},
          ]
        }
      ],
    };

    for (int i = 0; i < categoriesData.length; i++) {
      final newCat = Category(
        name: categoriesData[i]['name'] as String,
        orderIndex: i,
        colorValue: categoriesData[i]['color'] as int,
        isEnabled: true,
      );
      final catId = await categoryRepo.saveCategory(newCat);
      
      final catName = categoriesData[i]['name'] as String;
      final categoryProducts = productsData[catName] as List? ?? [];

      for (var pData in categoryProducts) {
        final pMap = pData as Map;
        final product = Product(
          name: pMap['name'] as String,
          priceCents: (pMap['price'] as num).toInt(),
          categoryId: catId,
          isEnabled: true,
          stockQuantity: 100,
          trackStock: false, 
        );
        final productResult = await productRepo.saveProduct(product);

        if (productResult.isSuccess) {
          final productId = productResult.value;
          final recipeList = pMap['recipe'] as List? ?? [];
          if (recipeList.isNotEmpty) {
            List<ProductIngredient> productIngredients = [];
            for (var rItem in recipeList) {
              final rMap = rItem as Map;
              final ingName = rMap['name'] as String;
              final qty = (rMap['qty'] as num).toDouble();
              final ingId = getIngId(ingName);
              if (ingId > 0) {
                productIngredients.add(ProductIngredient(
                  productId: productId,
                  ingredientId: ingId,
                  quantityNeeded: qty,
                ));
              }
            }
            if (productIngredients.isNotEmpty) {
              await ingredientRepo.saveRecipe(productId, productIngredients);
            }
          }
        }
      }
    }

    await loadCategories();
    ref.read(productProvider.notifier).loadProducts();
    print('✅ French Data Seeding Complete.');
  }

  Future<void> addCategory(String name, int colorValue, {String? imagePath}) async {
    final newCategory = Category(
      name: name,
      orderIndex: state.length,
      colorValue: colorValue,
      imagePath: imagePath,
    );
    final repo = ref.read(categoryRepositoryProvider);
    await repo.saveCategory(newCategory);
    await loadCategories();
  }

  Future<void> editCategory(int id, String name, int colorValue, {String? imagePath}) async {
    final existing = state.firstWhere((c) => c.id == id);
    final updated = existing.copyWith(
      name: name,
      colorValue: colorValue,
      imagePath: imagePath,
    );
    final repo = ref.read(categoryRepositoryProvider);
    await repo.updateCategory(updated);
    await loadCategories();
  }

  Future<void> toggleStatus(int id) async {
    final existing = state.firstWhere((c) => c.id == id);
    final updated = existing.copyWith(isEnabled: !existing.isEnabled);
    final repo = ref.read(categoryRepositoryProvider);
    await repo.updateCategory(updated);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.deleteCategory(id);
    await loadCategories();
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<Category>>(CategoryNotifier.new);
