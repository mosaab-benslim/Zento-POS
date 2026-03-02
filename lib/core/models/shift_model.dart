// lib/core/models/shift_model.dart

enum ShiftStatus { open, closed }

class ShiftModel {
  final int? id;
  final int userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingCash;
  final double? closingCash;
  final double totalSales;
  final double totalCashSales;
  final double totalCardSales;
  final double expectedCash;
  final double cashDifference;
  final ShiftStatus status;
  final String? userName; // ✅ Added for display in dashboard

  const ShiftModel({
    this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.openingCash,
    this.closingCash,
    this.totalSales = 0.0,
    this.totalCashSales = 0.0,
    this.totalCardSales = 0.0,
    this.expectedCash = 0.0,
    this.cashDifference = 0.0,
    this.status = ShiftStatus.open,
    this.userName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'openingCash': openingCash,
      'closingCash': closingCash,
      'totalSales': totalSales,
      'totalCashSales': totalCashSales,
      'totalCardSales': totalCardSales,
      'expectedCash': expectedCash,
      'cashDifference': cashDifference,
      'status': status.name.toUpperCase(),
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
      openingCash: (map['openingCash'] as num).toDouble(),
      closingCash: map['closingCash'] != null ? (map['closingCash'] as num).toDouble() : null,
      totalSales: (map['totalSales'] as num).toDouble(),
      totalCashSales: (map['totalCashSales'] as num).toDouble(),
      totalCardSales: (map['totalCardSales'] as num).toDouble(),
      expectedCash: (map['expectedCash'] as num).toDouble(),
      cashDifference: (map['cashDifference'] as num).toDouble(),
      status: ShiftStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['status'] as String),
        orElse: () => ShiftStatus.open,
      ),
      userName: map['userName'] as String?,
    );
  }

  ShiftModel copyWith({
    int? id,
    int? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? openingCash,
    double? closingCash,
    double? totalSales,
    double? totalCashSales,
    double? totalCardSales,
    double? expectedCash,
    double? cashDifference,
    ShiftStatus? status,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      openingCash: openingCash ?? this.openingCash,
      closingCash: closingCash ?? this.closingCash,
      totalSales: totalSales ?? this.totalSales,
      totalCashSales: totalCashSales ?? this.totalCashSales,
      totalCardSales: totalCardSales ?? this.totalCardSales,
      expectedCash: expectedCash ?? this.expectedCash,
      cashDifference: cashDifference ?? this.cashDifference,
      status: status ?? this.status,
      userName: userName ?? this.userName,
    );
  }
}
