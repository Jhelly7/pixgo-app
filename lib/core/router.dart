import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main/main_shell.dart';
import '../screens/main/home_screen.dart';
import '../screens/main/catalog_screen.dart';
import '../screens/main/channels_screen.dart';
import '../screens/main/mylist_screen.dart';
import '../screens/main/search_screen.dart';
import '../screens/main/account_screen.dart';
import '../screens/main/downloads_screen.dart';
import '../screens/main/plans_screen.dart';
import '../screens/main/checkout_screen.dart';
import '../screens/main/content_detail_screen.dart';
import '../screens/main/watch_screen.dart';
import '../screens/splash_screen.dart';

/// Rotas espelhando 1:1 a estrutura de pastas do Next.js App Router:
///   /                       → splash / redirect
///   /auth/login             /auth/register
///   /main                   /main/catalog   /main/channels   /main/mylist
///   /main/search            /main/account   /main/downloads
///   /main/plans             /main/plans/checkout
///   /main/content/:id       /main/watch/:id
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loggingIn = state.matchedLocation.startsWith('/auth');
      final atSplash = state.matchedLocation == '/';

      if (!auth.hydrated) return null;
      if (atSplash) return auth.isLoggedIn ? '/main' : '/auth/login';
      if (!auth.isLoggedIn && !loggingIn) return '/auth/login';
      if (auth.isLoggedIn && loggingIn) return '/main';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/main', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/main/catalog', builder: (c, s) => const CatalogScreen()),
          GoRoute(path: '/main/channels', builder: (c, s) => const ChannelsScreen()),
          GoRoute(path: '/main/mylist', builder: (c, s) => const MyListScreen()),
          GoRoute(path: '/main/search', builder: (c, s) => const SearchScreen()),
          GoRoute(path: '/main/account', builder: (c, s) => const AccountScreen()),
          GoRoute(path: '/main/downloads', builder: (c, s) => const DownloadsScreen()),
          GoRoute(path: '/main/plans', builder: (c, s) => const PlansScreen()),
          GoRoute(
            path: '/main/plans/checkout',
            builder: (c, s) => CheckoutScreen(planType: s.uri.queryParameters['plan'] ?? 'monthly'),
          ),
          GoRoute(
            path: '/main/content/:id',
            builder: (c, s) => ContentDetailScreen(id: s.pathParameters['id']!),
          ),
        ],
      ),

      // Watch fica fora da shell (fullscreen, sem bottom nav)
      GoRoute(
        path: '/main/watch/:id',
        builder: (c, s) => WatchScreen(
          id: s.pathParameters['id']!,
          offline: s.uri.queryParameters['offline'] == '1',
        ),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
