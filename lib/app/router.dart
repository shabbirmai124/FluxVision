import 'package:go_router/go_router.dart';

import '../features/blueprint/blueprint_screen.dart';
import '../features/scanner/scanner_screen.dart';
import '../features/vault/vault_screen.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/scanner',
    routes: <RouteBase>[
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const VaultScreen(),
      ),
      GoRoute(
        path: '/blueprint/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BlueprintScreen(sessionId: id);
        },
      ),
    ],
  );
}
