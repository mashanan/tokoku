import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/data/cart_repository.dart';
import '../responsive/breakpoints.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _cartIndex = 1;

const _destinations = [
  _Destination('Shop', Icons.storefront_outlined, Icons.storefront),
  _Destination('Cart', Icons.shopping_cart_outlined, Icons.shopping_cart),
  _Destination('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('Profile', Icons.person_outline, Icons.person),
];

/// Main navigation: a bottom bar on phones, a side rail on tablets.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Every tab opens on its main screen, even if a sub-page (an address, an
    // order, checkout) was open when the user left it.
    navigationShell.goBranch(index, initialLocation: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowSize = context.windowSize;
    final cartCount = ref.watch(cartCountProvider);

    Widget icon(int index, IconData data) {
      if (index != _cartIndex) return Icon(data);
      return Badge(
        isLabelVisible: cartCount > 0,
        label: Text(cartCount > 99 ? '99+' : '$cartCount'),
        child: Icon(data),
      );
    }

    if (windowSize == WindowSize.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (final (i, d) in _destinations.indexed)
              NavigationDestination(icon: icon(i, d.icon), selectedIcon: icon(i, d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    final extended = windowSize == WindowSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              extended: extended,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                for (final (i, d) in _destinations.indexed)
                  NavigationRailDestination(
                    icon: icon(i, d.icon),
                    selectedIcon: icon(i, d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
