enum OrderType { dineIn, takeaway, delivery }
enum OrderStatus { completed, pending, voided, preparing, ready }
enum PaymentMethod { cash, card, payOnDelivery }

class OrderModel {
  final int? id;
  final OrderType orderType;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final int totalCents; 
  final DateTime createdAt;
  final int cashierId; 
  final int? shiftId;
  final int queueNumber; 
  final String? tableName;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? kotPrintedAt;

  const OrderModel({
    this.id,
    required this.orderType,
    this.status = OrderStatus.completed,
    this.paymentMethod = PaymentMethod.cash,
    required this.totalCents,
    required this.createdAt,
    required this.cashierId,
    this.shiftId,
    required this.queueNumber,
    this.tableName,
    this.preparingAt,
    this.readyAt,
    this.kotPrintedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cashierId': cashierId,
      'shiftId': shiftId,
      'orderType': orderType.index,
      'status': status.index,
      'paymentMethod': paymentMethod.index,
      'totalAmount': totalCents, 
      'timestamp': createdAt.millisecondsSinceEpoch,
      'queueNumber': queueNumber,
      'tableName': tableName,
      'preparing_at': preparingAt?.millisecondsSinceEpoch,
      'ready_at': readyAt?.millisecondsSinceEpoch,
      'kot_printed_at': kotPrintedAt?.millisecondsSinceEpoch,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as int?,
      orderType: OrderType.values[map['orderType'] as int],
      status: OrderStatus.values[map['status'] as int? ?? 0],
      paymentMethod: PaymentMethod.values[map['paymentMethod'] as int? ?? 0],
      totalCents: (map['totalAmount'] as num).round(), 
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      cashierId: map['cashierId'] as int,
      shiftId: map['shiftId'] as int?,
      queueNumber: map['queueNumber'] as int? ?? 0,
      tableName: map['tableName'] as String?,
      preparingAt: map['preparing_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['preparing_at'] as int) : null,
      readyAt: map['ready_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['ready_at'] as int) : null,
      kotPrintedAt: map['kot_printed_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['kot_printed_at'] as int) : null,
    );
  }

  OrderModel copyWith({
    int? id,
    OrderType? orderType,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    int? totalCents,
    DateTime? createdAt,
    int? cashierId,
    int? shiftId,
    int? queueNumber,
    String? tableName,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalCents: totalCents ?? this.totalCents,
      createdAt: createdAt ?? this.createdAt,
      cashierId: cashierId ?? this.cashierId,
      shiftId: shiftId ?? this.shiftId,
      queueNumber: queueNumber ?? this.queueNumber,
      tableName: tableName ?? this.tableName,
      preparingAt: preparingAt ?? this.preparingAt,
      readyAt: readyAt ?? this.readyAt,
      kotPrintedAt: kotPrintedAt ?? this.kotPrintedAt,
    );
  }
}
