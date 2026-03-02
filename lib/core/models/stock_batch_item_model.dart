class StockBatchItem {
  final int? id;
  final int batchId;
  final int ingredientId;
  final String ingredientName; // Denormalized for display history
  final double quantityReceived;
  final double costPerUnit;
  final double subtotal;
  final DateTime? expiryDate;

  StockBatchItem({
    this.id,
    required this.batchId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantityReceived,
    required this.costPerUnit,
    required this.subtotal,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'quantityReceived': quantityReceived,
      'costPerUnit': costPerUnit,
      'subtotal': subtotal,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory StockBatchItem.fromMap(Map<String, dynamic> map) {
    return StockBatchItem(
      id: map['id'] as int?,
      batchId: map['batchId'] as int,
      ingredientId: map['ingredientId'] as int,
      ingredientName: map['ingredientName'] as String,
      quantityReceived: (map['quantityReceived'] as num).toDouble(),
      costPerUnit: (map['costPerUnit'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
    );
  }
}
