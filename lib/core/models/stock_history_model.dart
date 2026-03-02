class StockHistory {
  final int? id;
  final int productId;
  final int changeAmount; // +5 or -2
  final String reason; // "Sale #123", "Restock", "Void #123"
  final DateTime timestamp;

  const StockHistory({
    this.id,
    required this.productId,
    required this.changeAmount,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'changeAmount': changeAmount,
      'reason': reason,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory StockHistory.fromMap(Map<String, dynamic> map) {
    return StockHistory(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      changeAmount: map['changeAmount'] as int,
      reason: map['reason'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
