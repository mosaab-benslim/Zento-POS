import '../models/product_model.dart';

class CartItem {
  // We use a unique ID for the cart item itself to handle duplicates with different modifiers
  final String id; 
  final Product product;
  final int quantity;
  // Storing addon names for now, ideally we store ProductAddon objects
  final List<ProductAddon> addons; 

  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.addons = const [],
  });

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    List<ProductAddon>? addons,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addons: addons ?? this.addons,
    );
  }
}
