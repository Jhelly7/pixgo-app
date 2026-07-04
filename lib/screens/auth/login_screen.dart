import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _showPw = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).login(_username.text.trim(), _password.text);
      if (mounted) context.go('/main');
    } on ApiException catch (e) {
      setState(() {
        _error = e.status == 401 ? 'Usuário ou senha incorretos.' : 'Falha ao entrar. Tente novamente.';
      });
    } catch (_) {
      setState(() => _error = 'Falha ao entrar. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).loading;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'Pixgo',
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Bem-vindo de volta',
                        style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Entre para continuar assistindo',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text('Nome de usuário', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _username,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Senha', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _password,
                      obscureText: !_showPw,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _showPw = !_showPw),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text('Não tem conta? ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          GestureDetector(
                            onTap: () => context.go('/auth/register'),
                            child: const Text('Criar conta',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
