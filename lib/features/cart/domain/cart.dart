import 'dart:math';

import '../../products/domain/product.dart';

/// What is stored in `users/{uid}/cartItems/{productId}`.
class CartEntry {
  const CartEntry({required this.productId, required this.quantity, this.selected = true});

  final String productId;
  final int quantity;

  /// Whether the item is ticked for checkout. Items start ticked.
  final bool selected;
}

/// A cart entry joined with the latest product data. [product] is null when
/// the product has been removed from the catalog.
class CartItem {
  const CartItem({required this.productId, required this.quantity, this.product, this.selected = true});

  final String productId;
  final int quantity;
  final Product? product;
  final bool selected;

  bool get isAvailable => product != null && product!.inStock;

  /// Ticked and actually buyable, so it goes into the next order.
  bool get isSelectedForCheckout => selected && isAvailable;

  /// Quantity that can actually be bought, in case stock dropped after it was added.
  int get purchasableQuantity => isAvailable ? min(quantity, product!.stock) : 0;

  bool get exceedsStock => isAvailable && quantity > product!.stock;

  double get originalTotal => isAvailable ? product!.price * purchasableQuantity : 0;

  double get total => isAvailable ? product!.discountedPrice * purchasableQuantity : 0;
}

/// How many buyable items are ticked, for the "Select all" checkbox.
enum CartSelection {
  none,
  some,
  all;

  static CartSelection of(List<CartItem> items) {
    final buyable = items.where((item) => item.isAvailable).toList();
    final selected = buyable.where((item) => item.selected).length;
    if (selected == 0) return none;
    return selected == buyable.length ? all : some;
  }
}

class CartSummary {
  const CartSummary({required this.itemCount, required this.subtotal, required this.discount});

  /// Totals over the items that can be bought; unavailable items are ignored.
  factory CartSummary.of(List<CartItem> items) {
    var itemCount = 0;
    var subtotal = 0.0;
    var total = 0.0;
    for (final item in items) {
      itemCount += item.purchasableQuantity;
      subtotal += item.originalTotal;
      total += item.total;
    }
    return CartSummary(itemCount: itemCount, subtotal: subtotal, discount: subtotal - total);
  }

  final int itemCount;

  /// Sum of prices before discounts.
  final double subtotal;
  final double discount;

  double get total => subtotal - discount;
}
