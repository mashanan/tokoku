import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/presentation/widgets/price_text.dart';
import '../../products/presentation/widgets/product_image.dart';
import '../data/cart_repository.dart';
import '../domain/cart.dart';
import 'widgets/quantity_stepper.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All items will be removed from your cart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(cartRepositoryProvider).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final hasItems = itemsAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (hasItems)
            TextButton(onPressed: () => _confirmClear(context, ref), child: const Text('Clear')),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const EmptyState(icon: Icons.cloud_off_outlined, title: 'Could not load your cart'),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse the shop and add products you like.',
              action: FilledButton.tonal(
                onPressed: () => context.go(AppRoutes.catalog),
                child: const Text('Start shopping'),
              ),
            );
          }

          // Totals and checkout only cover the ticked items.
          final summary = CartSummary.of(items.where((item) => item.isSelectedForCheckout).toList());
          final list = Column(
            children: [
              _SelectAllBar(items: items),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _CartItemTile(item: items[index]),
                ),
              ),
            ],
          );

          // Tablets keep the order summary in a side panel.
          if (context.windowSize == WindowSize.expanded) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                SizedBox(
                  width: 360,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(child: _CartSummaryPanel(summary: summary)),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: list),
              Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(top: false, child: _CartSummaryPanel(summary: summary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Select all" checkbox above the cart. Shows a dash when only some items are ticked.
class _SelectAllBar extends ConsumerWidget {
  const _SelectAllBar({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = CartSelection.of(items);
    final buyableIds = [for (final item in items) if (item.isAvailable) item.productId];
    final selectedCount = items.where((item) => item.isSelectedForCheckout).length;

    // Ticking a partly ticked list selects everything, like most shopping apps.
    void toggle() => ref.read(cartRepositoryProvider).setAllSelected(buyableIds, selection != CartSelection.all);

    return InkWell(
      onTap: buyableIds.isEmpty ? null : toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: switch (selection) {
                CartSelection.all => true,
                CartSelection.none => false,
                CartSelection.some => null,
              },
              onChanged: buyableIds.isEmpty ? null : (_) => toggle(),
              semanticLabel: 'Select all items',
            ),
            const SizedBox(width: 4),
            Expanded(child: Text('Select all', style: Theme.of(context).textTheme.titleSmall)),
            Text(
              '$selectedCount of ${buyableIds.length} selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final product = item.product;
    final cart = ref.read(cartRepositoryProvider);

    return Dismissible(
      key: ValueKey(item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => cart.remove(item.productId),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: product == null ? null : () => context.push(AppRoutes.productDetail(product.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Lines the checkbox up with the middle of the photo.
                  padding: const EdgeInsets.only(top: 20),
                  child: Checkbox(
                    value: item.isSelectedForCheckout,
                    // Sold-out or removed products can't be bought, so they can't be ticked.
                    onChanged: item.isAvailable
                        ? (value) => cart.setSelected(item.productId, value ?? false)
                        : null,
                    semanticLabel: 'Select ${product?.title ?? 'item'} for checkout',
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(dimension: 88, child: ProductImage(url: product?.thumbnail ?? '')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product?.title ?? 'Unavailable product',
                              style: theme.textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => cart.remove(item.productId),
                          ),
                        ],
                      ),
                      if (item.isAvailable) ...[
                        PriceText(product: product!),
                        if (item.exceedsStock)
                          Text(
                            'Only ${product.stock} left. Quantity adjusted.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          ),
                        const SizedBox(height: 8),
                        QuantityStepper(
                          value: item.purchasableQuantity,
                          max: product.stock,
                          onChanged: (quantity) => cart.setQuantity(item.productId, quantity),
                        ),
                      ] else
                        Text(
                          product == null ? 'No longer available' : 'Out of stock',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartSummaryPanel extends StatelessWidget {
  const _CartSummaryPanel({required this.summary});

  final CartSummary summary;

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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Subtotal (${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'})',
              formatPrice(summary.subtotal)),
          if (summary.discount > 0)
            row('Discount', '-${formatPrice(summary.discount)}',
                style: TextStyle(color: theme.colorScheme.primary)),
          const Divider(height: 20),
          row('Total', formatPrice(summary.total), style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: summary.itemCount == 0 ? null : () => context.go(AppRoutes.checkout),
            child: Text(summary.itemCount == 0 ? 'Select items to check out' : 'Checkout (${summary.itemCount})'),
          ),
        ],
      ),
    );
  }
}
