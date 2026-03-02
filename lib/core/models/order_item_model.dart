class OrderItem {
  final int? id;
  final int orderId; // Links to the parent Order
  final int productId;
  final String productName;
  final int quantity;
  final int priceCents; // Changed from double price
  final String? modifiers; // ✅ KOT

  const OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.priceCents,
    this.modifiers,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'priceAtTime': priceCents, // Store as cents
      'modifiers': modifiers,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['orderId'] as int,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      priceCents: (map['priceAtTime'] as num).round(),
      modifiers: map['modifiers'] as String?,
    );
  }

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? productName,
    int? quantity,
    int? priceCents,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      priceCents: priceCents ?? this.priceCents,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}
