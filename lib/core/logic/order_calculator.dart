import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class OrderCalculator {
  /// Calculates total price for a single CartItem including addons
  static int calculateItemTotal(CartItem item) {
    int basePrice = item.product.priceCents;
    int addonsPrice = 0;
    
    for (var addon in item.addons) {
      addonsPrice += addon.priceCents;
    }

    return (basePrice + addonsPrice) * item.quantity;
  }

  /// Calculates the subtotal of the cart in cents
  static int calculateSubtotal(List<CartItem> items) {
    int total = 0;
    for (var item in items) {
      total += calculateItemTotal(item);
    }
    return total;
  }

  /// Calculates tax (example 19%)
  static int calculateTax(int subtotal) {
    // Example: 19% VAT
    // return (subtotal * 0.19).round();
    return 0; // Keeping 0 for now as per current logic
  }
}
