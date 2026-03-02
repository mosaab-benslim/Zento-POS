class Expense {
  final int? id;
  final String description;
  final double amount;
  final String category;
  final DateTime timestamp;
  final int? shiftId;
  final bool wasPaidFromDrawer;

  Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.timestamp,
    this.shiftId,
    this.wasPaidFromDrawer = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'shiftId': shiftId,
      'wasPaidFromDrawer': wasPaidFromDrawer ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      shiftId: map['shiftId'] as int?,
      wasPaidFromDrawer: (map['wasPaidFromDrawer'] as int? ?? 0) == 1,
    );
  }

  Expense copyWith({
    int? id,
    String? description,
    double? amount,
    String? category,
    DateTime? timestamp,
    int? shiftId,
    bool? wasPaidFromDrawer,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      shiftId: shiftId ?? this.shiftId,
      wasPaidFromDrawer: wasPaidFromDrawer ?? this.wasPaidFromDrawer,
    );
  }
}
