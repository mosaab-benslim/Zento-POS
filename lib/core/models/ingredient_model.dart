class Ingredient {
  final int? id;
  final String name;
  final double currentStock;
  final String unit; // e.g., "kg", "grams", "pcs", "ml"
  final double costPerUnit;
  final double reorderLevel;

  Ingredient({
    this.id,
    required this.name,
    this.currentStock = 0,
    required this.unit,
    this.costPerUnit = 0,
    this.reorderLevel = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currentStock': currentStock,
      'unit': unit,
      'costPerUnit': costPerUnit,
      'reorderLevel': reorderLevel,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as int?,
      name: map['name'] as String,
      currentStock: (map['currentStock'] as num).toDouble(),
      unit: map['unit'] as String,
      costPerUnit: (map['costPerUnit'] as num? ?? 0).toDouble(),
      reorderLevel: (map['reorderLevel'] as num? ?? 0).toDouble(),
    );
  }

  Ingredient copyWith({
    int? id,
    String? name,
    double? currentStock,
    String? unit,
    double? costPerUnit,
    double? reorderLevel,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      currentStock: currentStock ?? this.currentStock,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      reorderLevel: reorderLevel ?? this.reorderLevel,
    );
  }
}
