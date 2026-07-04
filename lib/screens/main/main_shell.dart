import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Equivalente mobile de MobileNav.tsx — barra inferior com 5 itens,
/// trocando "Buscar" por "Downloads" quando o plano permite (igual ao site).
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    {'path': '/main', 'icon': Icons.home_rounded, 'label': 'Início'},
    {'path': '/main/catalog', 'icon': Icons.movie_rounded, 'label': 'Catálogo'},
    {'path': '/main/channels', 'icon': Icons.live_tv_rounded, 'label': 'TV'},
    {'path': '/main/mylist', 'icon': Icons.bookmark_rounded, 'label': 'Minha Lista'},
    {'path': '/main/search', 'icon': Icons.search_rounded, 'label': 'Buscar'},
  ];

  int _currentIndex(String location) {
    for (int i = _tabs.length - 1; i >= 0; i--) {
      final path = _tabs[i]['path'] as String;
      if (path == '/main' ? location == '/main' : location.startsWith(path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _currentIndex(location);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          'Pixgo',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Conta',
            onPressed: () => context.go('/main/account'),
          ),
          if (!(auth.plan != null && auth.plan!.id != 'free'))
            IconButton(
              icon: const Icon(Icons.bolt_rounded, color: AppColors.primary),
              tooltip: 'Assinar Premium',
              onPressed: () => context.go('/main/plans'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i]['path'] as String),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t['icon'] as IconData),
                  label: t['label'] as String,
                ))
            .toList(),
      ),
    );
  }
}
