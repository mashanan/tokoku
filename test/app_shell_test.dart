import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tokoku/core/widgets/app_shell.dart';
import 'package:tokoku/features/cart/data/cart_repository.dart';

Widget _page(String name) => Scaffold(body: Center(child: Text('page:$name')));

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (c, s) => _page('shop'))]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/cart',
                builder: (c, s) => _page('cart'),
                routes: [GoRoute(path: 'checkout', builder: (c, s) => _page('checkout'))],
              ),
            ]),
            StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (c, s) => _page('orders'))]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => _page('profile'),
                routes: [GoRoute(path: 'addresses', builder: (c, s) => _page('addresses'))],
              ),
            ]),
          ],
        ),
      ],
    );

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  // A phone-sized screen, so the shell shows the bottom navigation bar.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = _router();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cartCountProvider.overrideWithValue(0)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching tabs opens the main screen, not the sub-page left open', (tester) async {
    final router = await _pumpApp(tester);

    router.go('/profile/addresses');
    await tester.pumpAndSettle();
    expect(find.text('page:addresses'), findsOneWidget);

    await _tapTab(tester, 'Shop');
    expect(find.text('page:shop'), findsOneWidget);

    await _tapTab(tester, 'Profile');
    expect(find.text('page:profile'), findsOneWidget);
    expect(find.text('page:addresses'), findsNothing);
  });

  testWidgets('the same holds for checkout in the cart tab', (tester) async {
    final router = await _pumpApp(tester);

    router.go('/cart/checkout');
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Orders');
    await _tapTab(tester, 'Cart');

    expect(find.text('page:cart'), findsOneWidget);
    expect(find.text('page:checkout'), findsNothing);
  });
}
