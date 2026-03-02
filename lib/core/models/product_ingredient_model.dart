class ProductIngredient {
  final int? id;
  final int productId;
  final int ingredientId;
  final double quantityNeeded;
  // Optional: Add metadata like ingredient name if needed for UI
  final String? ingredientName;
  final String? ingredientUnit;

  ProductIngredient({
    this.id,
    required this.productId,
    required this.ingredientId,
    required this.quantityNeeded,
    this.ingredientName,
    this.ingredientUnit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'ingredientId': ingredientId,
      'quantityNeeded': quantityNeeded,
      'ingredientUnit': ingredientUnit,
    };
  }

  factory ProductIngredient.fromMap(Map<String, dynamic> map) {
    return ProductIngredient(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      ingredientId: map['ingredientId'] as int,
      quantityNeeded: (map['quantityNeeded'] as num).toDouble(),
      ingredientName: map['ingredientName'] as String?,
      ingredientUnit: map['ingredientUnit'] as String?,
    );
  }

  ProductIngredient copyWith({
    int? id,
    int? productId,
    int? ingredientId,
    double? quantityNeeded,
    String? ingredientName,
    String? ingredientUnit,
  }) {
    return ProductIngredient(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      ingredientId: ingredientId ?? this.ingredientId,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      ingredientName: ingredientName ?? this.ingredientName,
      ingredientUnit: ingredientUnit ?? this.ingredientUnit,
    );
  }
}
