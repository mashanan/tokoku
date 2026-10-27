import 'package:tokoku/features/cart/domain/cart.dart';
import 'package:tokoku/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({double price = 10, double discount = 0, int stock = 10}) {
  return Product(
    id: 'p',
    title: 'Product',
    description: '',
    category: 'misc',
    price: price,
    discountPercentage: discount,
    rating: 4,
    stock: stock,
    thumbnail: '',
    images: const [],
  );
}

void main() {
  test('sums subtotal, discount and total over items', () {
    final summary = CartSummary.of([
      CartItem(productId: 'a', quantity: 2, product: _product(price: 10)),
      CartItem(productId: 'b', quantity: 1, product: _product(price: 50, discount: 20)),
    ]);

    expect(summary.itemCount, 3);
    expect(summary.subtotal, 70);
    expect(summary.discount, closeTo(10, 0.001));
    expect(summary.total, closeTo(60, 0.001));
  });

  test('ignores removed and out-of-stock products', () {
    final summary = CartSummary.of([
      const CartItem(productId: 'gone', quantity: 3),
      CartItem(productId: 'empty', quantity: 2, product: _product(stock: 0)),
      CartItem(productId: 'ok', quantity: 1, product: _product(price: 5)),
    ]);

    expect(summary.itemCount, 1);
    expect(summary.total, 5);
  });

  test('caps the quantity at the current stock', () {
    final item = CartItem(productId: 'a', quantity: 8, product: _product(price: 2, stock: 3));

    expect(item.exceedsStock, isTrue);
    expect(item.purchasableQuantity, 3);
    expect(item.total, 6);
  });

  group('selection', () {
    CartItem item(String id, {bool selected = true, int stock = 10}) =>
        CartItem(productId: id, quantity: 1, product: _product(stock: stock), selected: selected);

    test('only ticked, buyable items go to checkout', () {
      expect(item('a').isSelectedForCheckout, isTrue);
      expect(item('a', selected: false).isSelectedForCheckout, isFalse);
      expect(item('a', stock: 0).isSelectedForCheckout, isFalse);
    });

    test('select all reflects the buyable items only', () {
      expect(CartSelection.of([item('a'), item('b')]), CartSelection.all);
      expect(CartSelection.of([item('a'), item('b', selected: false)]), CartSelection.some);
      expect(CartSelection.of([item('a', selected: false), item('b', selected: false)]), CartSelection.none);
      // A ticked but sold-out item doesn't stop "all" from being shown.
      expect(CartSelection.of([item('a'), item('b', stock: 0, selected: false)]), CartSelection.all);
      expect(CartSelection.of(const []), CartSelection.none);
    });

    test('the summary can cover just the ticked items', () {
      final items = [item('a'), item('b', selected: false)];
      final summary = CartSummary.of(items.where((i) => i.isSelectedForCheckout).toList());
      expect(summary.itemCount, 1);
      expect(summary.total, 10);
    });
  });
}
