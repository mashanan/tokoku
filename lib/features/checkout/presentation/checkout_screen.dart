import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../addresses/data/address_repository.dart';
import '../../addresses/domain/address.dart';
import '../../addresses/presentation/widgets/address_card.dart';
import '../../cart/data/cart_repository.dart';
import '../../cart/domain/cart.dart';
import '../../orders/domain/order.dart';
import '../../products/presentation/widgets/product_image.dart';
import '../data/checkout_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// Address picked on this screen; null means "use the default address".
  String? _selectedAddressId;
  ShippingMethod _shippingMethod = ShippingMethod.standard;
  PaymentMethod _paymentMethod = PaymentMethod.card;
  bool _isPlacing = false;

  SavedAddress? _selectedAddress(List<SavedAddress> addresses) {
    return addresses.where((a) => a.id == _selectedAddressId).firstOrNull ?? ref.watch(defaultAddressProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addAddress() async {
    final id = await context.push<String>(AppRoutes.newAddress);
    if (id != null && mounted) setState(() => _selectedAddressId = id);
  }

  Future<void> _chooseAddress(SavedAddress? current) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddressPickerSheet(selectedId: current?.id),
    );
    if (id != null && mounted) setState(() => _selectedAddressId = id);
  }

  Future<void> _placeOrder(SavedAddress? address) async {
    if (address == null) {
      _showMessage('Please add a shipping address.');
      return;
    }

    setState(() => _isPlacing = true);
    try {
      // Only the ticked items are ordered; the rest stay in the cart.
      final selectedItems = (ref.read(cartItemsProvider).value ?? const <CartItem>[])
          .where((item) => item.isSelectedForCheckout);
      final orderId = await ref.read(checkoutRepositoryProvider).placeOrder(
            entries: [
              for (final item in selectedItems) CartEntry(productId: item.productId, quantity: item.quantity),
            ],
            address: address.address,
            shippingMethod: _shippingMethod,
            paymentMethod: _paymentMethod,
          );
      if (mounted) context.go(AppRoutes.orderPlaced(orderId));
    } on CheckoutException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not place your order. Please try again.');
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load your cart'),
        data: (items) {
          final available = items.where((item) => item.isSelectedForCheckout).toList();
          if (available.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Nothing to check out',
              message: items.isEmpty
                  ? 'Add some products to your cart first.'
                  : 'Tick the items you want to buy in your cart.',
              action: FilledButton.tonal(
                onPressed: () => context.go(items.isEmpty ? AppRoutes.catalog : AppRoutes.cart),
                child: Text(items.isEmpty ? 'Start shopping' : 'Back to cart'),
              ),
            );
          }

          final address = _selectedAddress(addressesAsync.value ?? const []);
          final summary = CartSummary.of(available);
          final total = summary.total + _shippingMethod.fee;
          final options = _buildOptions(context, addressesAsync, address);
          final orderSummary = _OrderSummary(items: available, summary: summary, shippingFee: _shippingMethod.fee);
          final placeOrderButton = FilledButton(
            onPressed: _isPlacing ? null : () => _placeOrder(address),
            child: _isPlacing
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Place order · ${formatPrice(total)}'),
          );

          // Tablets keep the order summary and button in a side panel.
          if (context.windowSize == WindowSize.expanded) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: options)),
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [orderSummary, const SizedBox(height: 16), placeOrderButton],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [options, const SizedBox(height: 24), orderSummary],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(
                  top: false,
                  child: Padding(padding: const EdgeInsets.all(16), child: placeOrderButton),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptions(BuildContext context, AsyncValue<List<SavedAddress>> addressesAsync, SavedAddress? address) {
    final Widget addressSection;
    if (addressesAsync.isLoading && !addressesAsync.hasValue) {
      addressSection = const Center(child: CircularProgressIndicator());
    } else if (address == null) {
      addressSection = OutlinedButton.icon(
        onPressed: _isPlacing ? null : _addAddress,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add shipping address'),
      );
    } else {
      addressSection = AddressCard(
        address: address,
        isDefault: address.id == ref.watch(defaultAddressProvider)?.id,
        onTap: _isPlacing ? null : () => _chooseAddress(address),
        trailing: TextButton(
          onPressed: _isPlacing ? null : () => _chooseAddress(address),
          child: const Text('Change'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Shipping address'),
        addressSection,
        const SizedBox(height: 24),
        const _SectionTitle('Delivery'),
        for (final method in ShippingMethod.values)
          _OptionTile(
            selected: method == _shippingMethod,
            icon: method == ShippingMethod.express ? Icons.rocket_launch_outlined : Icons.local_shipping_outlined,
            title: method.label,
            subtitle: method.description,
            trailing: method.fee == 0 ? 'Free' : formatPrice(method.fee),
            onTap: _isPlacing ? null : () => setState(() => _shippingMethod = method),
          ),
        const SizedBox(height: 24),
        const _SectionTitle('Payment'),
        for (final method in PaymentMethod.values)
          _OptionTile(
            selected: method == _paymentMethod,
            icon: switch (method) {
              PaymentMethod.card => Icons.credit_card,
              PaymentMethod.cashOnDelivery => Icons.payments_outlined,
              PaymentMethod.bankTransfer => Icons.account_balance_outlined,
            },
            title: method.label,
            onTap: _isPlacing ? null : () => setState(() => _paymentMethod = method),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Demo checkout: no real payment is processed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet listing saved addresses. Pops with the chosen address id.
class _AddressPickerSheet extends ConsumerWidget {
  const _AddressPickerSheet({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider).value ?? const [];
    final defaultId = ref.watch(defaultAddressProvider)?.id;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const _SectionTitle('Deliver to'),
            for (final address in addresses)
              AddressCard(
                address: address,
                isDefault: address.id == defaultId,
                selected: address.id == selectedId,
                onTap: () => Navigator.pop(context, address.id),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final id = await context.push<String>(AppRoutes.newAddress);
                if (id != null && context.mounted) Navigator.pop(context, id);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add new address'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A selectable card that behaves like a radio button.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: selected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? colorScheme.primary : colorScheme.outlineVariant),
      ),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) Text(trailing!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.items, required this.summary, required this.shippingFee});

  final List<CartItem> items;
  final CartSummary summary;
  final double shippingFee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label, style: style), Text(value, style: style)],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Order summary'),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(dimension: 48, child: ProductImage(url: item.product!.thumbnail)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${item.product!.title} × ${item.purchasableQuantity}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatPrice(item.total)),
              ],
            ),
          ),
        const Divider(height: 20),
        row('Subtotal', formatPrice(summary.subtotal)),
        if (summary.discount > 0)
          row('Discount', '-${formatPrice(summary.discount)}', style: TextStyle(color: theme.colorScheme.primary)),
        row('Shipping', shippingFee == 0 ? 'Free' : formatPrice(shippingFee)),
        const Divider(height: 20),
        row('Total', formatPrice(summary.total + shippingFee), style: theme.textTheme.titleMedium),
      ],
    );
  }
}
