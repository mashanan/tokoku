import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/constrained_content.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import 'widgets/order_card.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your orders',
          message: 'Please try again in a moment.',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(userOrdersProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (allOrders) {
          final now = DateTime.now();
          final orders = allOrders.where((order) => !order.isHiddenFromHistory(now)).toList();
          const retentionNote =
              'Completed and cancelled orders are kept here for $orderHistoryMonths months after you place them.';

          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: allOrders.isEmpty ? 'Orders you place will show up here.' : retentionNote,
              action: FilledButton.tonal(
                onPressed: () => context.go(AppRoutes.catalog),
                child: const Text('Start shopping'),
              ),
            );
          }

          return ConstrainedContent(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == orders.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      retentionNote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final order = orders[index];
                return OrderCard(order: order, onTap: () => context.go(AppRoutes.orderDetail(order.id)));
              },
            ),
          );
        },
      ),
    );
  }
}
