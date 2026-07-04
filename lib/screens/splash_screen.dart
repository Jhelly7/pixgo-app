import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'language_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _checkedLang = false;
  bool _needsLang = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final has = await ref.read(localeProvider.notifier).hasChosenLanguage();
    if (!mounted) return;
    setState(() {
      _needsLang = !has;
      _checkedLang = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!_checkedLang) {
      return const _LoadingBody();
    }
    if (_needsLang) {
      return const LanguageScreen();
    }
    if (!auth.hydrated) {
      return const _LoadingBody();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(auth.isLoggedIn ? '/main' : '/auth/login');
    });
    return const _LoadingBody();
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pixgo',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontWeight: FontWeight.w900,
                fontSize: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}
