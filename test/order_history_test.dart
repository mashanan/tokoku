import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku/features/addresses/domain/address.dart';
import 'package:tokoku/features/orders/domain/order.dart';

Order _order(OrderStatus status, DateTime? createdAt) {
  return Order(
    id: 'order-123',
    userId: 'alice',
    items: const [],
    subtotal: 0,
    discount: 0,
    shippingFee: 0,
    total: 0,
    status: status,
    shippingAddress: const ShippingAddress(
      fullName: '',
      phone: '',
      street: '',
      city: '',
      postalCode: '',
      country: '',
    ),
    shippingMethod: ShippingMethod.standard,
    paymentMethod: PaymentMethod.card,
    createdAt: createdAt,
  );
}

void main() {
  final placed = DateTime(2026, 1, 15, 10, 30);

  test('finished orders stay in the history until three months have passed', () {
    final delivered = _order(OrderStatus.delivered, placed);
    expect(delivered.isHiddenFromHistory(DateTime(2026, 4, 15, 10, 29)), isFalse);
    expect(delivered.isHiddenFromHistory(DateTime(2026, 4, 15, 10, 30)), isTrue);
    expect(delivered.isHiddenFromHistory(DateTime(2026, 9, 1)), isTrue);
  });

  test('cancelled orders are hidden after three months too', () {
    expect(_order(OrderStatus.cancelled, placed).isHiddenFromHistory(DateTime(2026, 5, 1)), isTrue);
  });

  test('orders still in progress are never hidden', () {
    for (final status in [OrderStatus.pending, OrderStatus.processing, OrderStatus.shipped]) {
      expect(_order(status, placed).isHiddenFromHistory(DateTime(2027, 1, 1)), isFalse, reason: status.name);
    }
  });

  test('orders whose server timestamp has not arrived yet stay visible', () {
    expect(_order(OrderStatus.delivered, null).isHiddenFromHistory(DateTime(2030)), isFalse);
  });
}
