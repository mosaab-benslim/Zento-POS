class ProductAddon {
  final int? id;
  final String name;
  final int priceCents; // Changed from double price
  final bool isEnabled;

  const ProductAddon({
    this.id,
    required this.name,
    required this.priceCents,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap(int productId) {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'price': priceCents, // Store as int in DB 
      'isEnabled': isEnabled ? 1 : 0,
    };
  }

  factory ProductAddon.fromMap(Map<String, dynamic> map) {
    return ProductAddon(
      id: map['id'] as int?,
      name: map['name'] as String,
      // Handle potential legacy double data from DB by rounding
      priceCents: (map['price'] as num).round(),
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
    );
  }
}

class Product {
  final int? id;
  final String name;
  final int priceCents; // Changed from double price
  final int costCents;  // Changed from double cost
  final String? imagePath;
  final int categoryId;
  final bool isEnabled;
  final List<ProductAddon> addons;

  // Inventory Fields
  final int stockQuantity;
  final bool trackStock; // 1 = true, 0 = false
  final int alertLevel;

  const Product({
    this.id,
    required this.name,
    required this.priceCents,
    this.costCents = 0,
    this.imagePath,
    required this.categoryId,
    this.isEnabled = true,
    this.addons = const [],
    this.stockQuantity = 0,
    this.trackStock = false,
    this.alertLevel = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': priceCents,
      'cost': costCents,
      'imagePath': imagePath,
      'categoryId': categoryId,
      'isEnabled': isEnabled ? 1 : 0,
      'stockQuantity': stockQuantity,
      'trackStock': trackStock ? 1 : 0,
      'alertLevel': alertLevel,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {List<ProductAddon> addons = const []}) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      priceCents: (map['price'] as num).round(),
      costCents: (map['cost'] as num? ?? 0).round(),
      imagePath: map['imagePath'] as String?,
      categoryId: map['categoryId'] as int,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      stockQuantity: map['stockQuantity'] as int? ?? 0,
      trackStock: (map['trackStock'] as int? ?? 0) == 1,
      alertLevel: map['alertLevel'] as int? ?? 5,
      addons: addons,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    int? priceCents,
    int? costCents,
    String? imagePath,
    int? categoryId,
    bool? isEnabled,
    List<ProductAddon>? addons,
    int? stockQuantity,
    bool? trackStock,
    int? alertLevel,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      costCents: costCents ?? this.costCents,
      imagePath: imagePath ?? this.imagePath,
      categoryId: categoryId ?? this.categoryId,
      isEnabled: isEnabled ?? this.isEnabled,
      addons: addons ?? this.addons,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackStock: trackStock ?? this.trackStock,
      alertLevel: alertLevel ?? this.alertLevel,
    );
  }
}
