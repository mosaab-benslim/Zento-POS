import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';
import '../models/order_item_model.dart'; 
import '../logic/order_calculator.dart';
import '../repositories/order_repository.dart';
import 'package:zento_pos/main.dart';

// 2. State Model: Current Order Status
class OrderState {
  final List<CartItem> items;
  final OrderType orderType;
  final int subtotalCents; 
  final bool isResumed; 
  final int? lastOrderId; // 🔥 Track last order for quick undo
  final int queueNumber; // 🔥 The actual display number
  final int? resumedOrderId; // 🔥 Original ID if this was a pending order

  OrderState({
    this.items = const [],
    this.orderType = OrderType.dineIn,
    this.subtotalCents = 0,
    this.isResumed = false,
    this.lastOrderId,
    this.queueNumber = 0,
    this.resumedOrderId,
  });

  OrderState copyWith({
    List<CartItem>? items,
    OrderType? orderType,
    int? subtotalCents,
    bool? isResumed,
    int? lastOrderId,
    int? queueNumber,
    int? resumedOrderId,
  }) {
    return OrderState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      isResumed: isResumed ?? this.isResumed,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      queueNumber: queueNumber ?? this.queueNumber,
      resumedOrderId: resumedOrderId ?? this.resumedOrderId,
    );
  }
}

// 3. The Logic (Controller)
class OrderLogic extends Notifier<OrderState> {
  @override
  OrderState build() {
    return OrderState();
  }

  Future<void> refreshQueueNumber() async {
    final repo = ref.read(orderRepositoryProvider);
    final nextNum = await repo.getNextQueueNumber();
    state = state.copyWith(queueNumber: nextNum);
  }

  // ✅ Add Product
  void addProduct(Product product, {List<ProductAddon> addons = const []}) {
    final addonKeys = addons.map((a) => a.name).join(',');
    
    final existingIndex = state.items.indexWhere((item) {
      final itemAddonKeys = item.addons.map((a) => a.name).join(',');
      return item.product.id == product.id && addonKeys == itemAddonKeys;
    });

    List<CartItem> newItems;

    if (existingIndex >= 0) {
      newItems = List.from(state.items);
      final currentItem = newItems[existingIndex];
      newItems[existingIndex] = currentItem.copyWith(quantity: currentItem.quantity + 1);
    } else {
      newItems = [
        ...state.items,
        CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product, 
          quantity: 1,
          addons: addons,
        )
      ];
    }

    state = state.copyWith(items: newItems);
    calculateTotal();
  }

  // ✅ Remove Product (Completely)
  void removeCartItem(CartItem item) {
    final newItems = state.items.where((i) => i.id != item.id).toList();
    state = state.copyWith(
      items: newItems,
      isResumed: newItems.isEmpty ? false : state.isResumed,
    );
    calculateTotal();
  }

  // ✅ Decrease Qty
  void decreaseQty(CartItem item) {
    final existingIndex = state.items.indexWhere((i) => i.id == item.id);
    if (existingIndex == -1) return;

    List<CartItem> newItems = List.from(state.items);
    final currentItem = newItems[existingIndex];

    if (currentItem.quantity > 1) {
      newItems[existingIndex] = currentItem.copyWith(quantity: currentItem.quantity - 1);
    } else {
      newItems.removeAt(existingIndex);
    }

    state = state.copyWith(
      items: newItems,
      isResumed: newItems.isEmpty ? false : state.isResumed,
    );
    calculateTotal();
  }

  // ✅ Calculate Total
  void calculateTotal() {
    final sum = OrderCalculator.calculateSubtotal(state.items);
    state = state.copyWith(subtotalCents: sum);
  }

  // ✅ Set Order Type
  void setOrderType(OrderType type) {
    state = state.copyWith(orderType: type);
  }

  // ✅ Clear Order
  void clearOrder() {
    state = OrderState(
      items: [], 
      orderType: OrderType.dineIn, 
      subtotalCents: 0, 
      isResumed: false, 
      lastOrderId: state.lastOrderId,
      queueNumber: state.queueNumber,
      resumedOrderId: null,
    );
  }

  // ✅ PREPARE ORDER (Does not clear cart yet)
  PreparedOrder? prepareOrder({required int cashierId}) {
    if (state.items.isEmpty) return null;

    final wasResumed = state.isResumed;

    final order = OrderModel(
      orderType: state.orderType,
      totalCents: state.subtotalCents,
      createdAt: DateTime.now().toUtc(),
      cashierId: cashierId,
      queueNumber: state.queueNumber, // ✅ Preserve existing or 0 if new
      status: OrderStatus.completed,  // ✅ Default to completed for prepareOrder
    );

    final List<OrderItem> orderItems = state.items.map((cartItem) {
      final addonNames = cartItem.addons.map((a) => a.name).join(", ");
      
      final singleItemTotal = OrderCalculator.calculateItemTotal(cartItem) ~/ cartItem.quantity;

      return OrderItem(
        orderId: 0,
        productId: cartItem.product.id ?? 0,
        productName: cartItem.product.name,
        quantity: cartItem.quantity,
        priceCents: singleItemTotal,
        modifiers: addonNames.isNotEmpty ? addonNames : null,
      );
    }).toList();

    return PreparedOrder(order, orderItems, wasResumed: wasResumed);
  }

  // 🔥 FINALIZE ORDER (Kept for compatibility, but now uses the two-step process internally or is replaced)
  PreparedOrder? finalizeOrder({required int cashierId}) {
    final prepared = prepareOrder(cashierId: cashierId);
    if (prepared != null) {
      clearOrder();
    }
    return prepared;
  }

  // 🔥 HOLD ORDER
  Future<void> holdOrder({required int cashierId, required WidgetRef ref}) async {
    if (state.items.isEmpty) return;
    
    final originalResumedId = state.resumedOrderId;
    final prepared = finalizeOrder(cashierId: cashierId);
    if (prepared != null) {
      // If we were resuming an existing pending order, we should delete the OLD one
      // because we are now creating a NEW one (with potentially updated items)
      final repo = ref.read(orderRepositoryProvider);
      if (originalResumedId != null) {
        await repo.deleteOrder(originalResumedId);
      }

      final pendingOrder = prepared.order.copyWith(status: OrderStatus.pending);
      await repo.createOrder(pendingOrder, prepared.items);
      ref.invalidate(pendingOrdersProvider);
    }
  }

  // 🔥 RESUME ORDER
  void resumeOrder({
    required OrderModel order, 
    required List<OrderItem> items, 
    required List<Product> allProducts,
    required WidgetRef ref,
  }) {
    clearOrder();
    
    final List<CartItem> newItems = [];
    for (var item in items) {
      Product? product;
      try {
        product = allProducts.firstWhere((p) => p.id == item.productId);
      } catch (e) {
        product = Product(
          id: item.productId,
          name: item.productName,
          priceCents: item.priceCents,
          categoryId: 0,
        );
      }

      newItems.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + item.productId.toString(),
        product: product,
        quantity: item.quantity,
        addons: [], 
      ));
    }

    state = state.copyWith(
      items: newItems,
      orderType: order.orderType,
      isResumed: true, 
      queueNumber: order.queueNumber, 
      resumedOrderId: order.id, // 🔥 Store the original ID
    );
    calculateTotal();

    // After resuming, we do NOT delete yet to prevent data loss if user switches
    ref.invalidate(pendingOrdersProvider);
  }

  // 🔥 QUICK UNDO
  Future<void> undoLastOrder(WidgetRef ref, List<Product> allProducts) async {
    final orderId = state.lastOrderId;
    if (orderId == null) return;

    final repo = ref.read(orderRepositoryProvider);
    final items = await repo.getOrderItems(orderId);
    final orders = await repo.getHistoricalOrders();
    final order = orders.firstWhere((o) => o.id == orderId);

    // 1. Void the order
    await repo.voidOrder(orderId);

    // 2. Resume items to cart
    resumeOrder(
      order: order,
      items: items,
      allProducts: allProducts,
      ref: ref,
    );
    
    // Clear last order since it's now in the cart
    state = state.copyWith(lastOrderId: null);
  }
}

// 5. Helper Class for Return Value
class PreparedOrder {
  final OrderModel order;
  final List<OrderItem> items;
  final bool wasResumed; // 🔥 ADDED
  PreparedOrder(this.order, this.items, {this.wasResumed = false});
}

// 4. The Riverpod Provider
final orderProvider = NotifierProvider<OrderLogic, OrderState>(OrderLogic.new);

// 🔥 NEW: Pending Orders Provider
final pendingOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return await repo.getPendingOrders();
});
