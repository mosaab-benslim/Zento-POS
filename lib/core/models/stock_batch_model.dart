class StockBatch {
  final int? id;
  final String supplierName;
  final String invoiceNumber;
  final String? invoiceImagePath;
  final double totalCost;
  final DateTime receivedDate;
  final String? notes;

  StockBatch({
    this.id,
    required this.supplierName,
    required this.invoiceNumber,
    this.invoiceImagePath,
    required this.totalCost,
    required this.receivedDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierName': supplierName,
      'invoiceNumber': invoiceNumber,
      'invoiceImagePath': invoiceImagePath,
      'totalCost': totalCost,
      'receivedDate': receivedDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    return StockBatch(
      id: map['id'] as int?,
      supplierName: map['supplierName'] as String,
      invoiceNumber: map['invoiceNumber'] as String,
      invoiceImagePath: map['invoiceImagePath'] as String?,
      totalCost: (map['totalCost'] as num).toDouble(),
      receivedDate: DateTime.parse(map['receivedDate'] as String),
      notes: map['notes'] as String?,
    );
  }
}
