import '../../addresses/domain/address.dart';

/// Finished orders stay in the customer's order history for this many months
/// after they were placed. They are only hidden, never deleted: admins still
/// see every order.
const orderHistoryMonths = 3;

enum OrderStatus {
  pending('Pending'),
  processing('Processing'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);

  final String label;

  /// The status an admin can move this order to next, or null when it's final.
  OrderStatus? get next => switch (this) {
        pending => processing,
        processing => shipped,
        shipped => delivered,
        delivered || cancelled => null,
      };

  /// Admins can cancel orders until they leave the warehouse.
  bool get canCancel => this == pending || this == processing;

  /// Customers can cancel only before the store starts working on the order.
  bool get canCustomerCancel => this == pending;
}

/// Who cancelled an order, stored in `cancelledBy`.
enum CancelledBy { customer, admin }

enum ShippingMethod {
  standard('Standard delivery', 'Arrives in 5–7 business days', 0),
  express('Express delivery', 'Arrives in 1–2 business days', 9.99);

  const ShippingMethod(this.label, this.description, this.fee);

  final String label;
  final String description;
  final double fee;
}

/// Payments are simulated; no money is charged.
enum PaymentMethod {
  card('Credit or debit card'),
  cashOnDelivery('Cash on delivery'),
  bankTransfer('Bank transfer');

  const PaymentMethod(this.label);

  final String label;
}

/// A product as it was when the order was placed, so later catalog changes
/// don't rewrite order history.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.title,
    required this.thumbnail,
    required this.unitPrice,
    required this.originalUnitPrice,
    required this.quantity,
  });

  final String productId;
  final String title;
  final String thumbnail;

  /// Price paid per unit, after discount.
  final double unitPrice;
  final double originalUnitPrice;
  final int quantity;

  double get total => unitPrice * quantity;
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.status,
    required this.shippingAddress,
    required this.shippingMethod,
    required this.paymentMethod,
    this.createdAt,
    this.statusTimes = const {},
    this.cancelledBy,
  });

  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double total;
  final OrderStatus status;
  final ShippingAddress shippingAddress;
  final ShippingMethod shippingMethod;
  final PaymentMethod paymentMethod;

  /// Null for a moment after placing the order, until the server timestamp arrives.
  final DateTime? createdAt;

  /// When the order reached each status after pending.
  final Map<OrderStatus, DateTime> statusTimes;

  /// Set once the order is cancelled.
  final CancelledBy? cancelledBy;

  DateTime? timeOf(OrderStatus status) => status == OrderStatus.pending ? createdAt : statusTimes[status];

  /// Short, human-friendly order number.
  String get number => id.substring(0, 8).toUpperCase();

  int get itemCount => items.fold(0, (count, item) => count + item.quantity);

  bool get isFinished => status == OrderStatus.delivered || status == OrderStatus.cancelled;

  /// Whether this order has dropped out of the customer's history at [now]:
  /// it is finished and was placed at least [orderHistoryMonths] months ago.
  /// Orders still in progress always stay visible.
  bool isHiddenFromHistory(DateTime now) {
    final placed = createdAt;
    if (!isFinished || placed == null) return false;
    final cutoff = DateTime(
      placed.year,
      placed.month + orderHistoryMonths,
      placed.day,
      placed.hour,
      placed.minute,
      placed.second,
    );
    return !now.isBefore(cutoff);
  }
}
