import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/categories/categories_routes.dart';
import '../features/developer/developer_routes.dart';
import '../features/receipts/presentation/receipt_list_screen.dart';
import '../features/receipts/presentation/receipt_routes_detail.dart';
import '../features/receipts/presentation/receipt_routes_review.dart';
import '../features/scan/scan_routes.dart';
import '../features/settings/presentation/settings_routes.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../l10n/generated/app_localizations.dart';

part 'router.g.dart';

abstract final class Routes {
  static const receipts = '/receipts';
  static const settings = '/settings';
}

/// Navigator above the bottom-nav shell: scanning, review and editing open
/// full screen.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.receipts,
    // An unknown location (a stale or mistyped deep link) goes to the receipt
    // list instead of go_router's untranslated error page.
    onException: (context, state, router) => router.go(Routes.receipts),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.receipts,
                builder: (context, state) => const ReceiptListScreen(),
                // `new` and `:id/edit` come before `:id` so they match first.
                routes: [
                  ...buildReviewReceiptChildRoutes(
                    parentNavigatorKey: _rootNavigatorKey,
                  ),
                  ...receiptDetailRoutes(),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [...settingsChildRoutes, ...categoriesRoutes],
              ),
            ],
          ),
        ],
      ),
      ...scanRoutes,
      ...reviewTopLevelRoutes,
      ...developerRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Android guidance: Back from a top-level destination returns to the start
    // destination (Receipts) before it leaves the app.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: l10n.navReceipts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
