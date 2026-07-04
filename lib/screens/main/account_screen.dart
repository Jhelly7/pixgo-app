import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _curPw = TextEditingController();
  final _newPw = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    final u = ref.read(authProvider).user;
    _name.text = u?.name ?? '';
    _email.text = u?.email ?? '';
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{};
      if (_name.text.trim().isNotEmpty) body['name'] = _name.text.trim();
      if (_email.text.trim().isNotEmpty) body['email'] = _email.text.trim();
      await authApi.update(body);
      await ref.read(authProvider.notifier).refreshMe();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPw.text.length < 8) return;
    setState(() => _saving = true);
    try {
      await authApi.changePassword({'current_password': _curPw.text, 'new_password': _newPw.text});
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/auth/login');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atual incorreta')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final plan = auth.plan;
    final isPremium = plan != null && plan.id != 'free';
    final initials = (user?.name.isNotEmpty == true ? user!.name : (user?.username ?? '?'))
        .split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configurações da Conta', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Perfil'), Tab(text: 'Segurança'), Tab(text: 'Assinatura')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // Perfil
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: AppColors.bgDarker, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: AppColors.primary,
                        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('@${user?.username ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPremium ? AppColors.primary.withOpacity(0.15) : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(plan?.id ?? 'free', style: const TextStyle(fontSize: 10)),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  const Text('Nome completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: _name),
                  const SizedBox(height: 12),
                  const Text('E-mail (opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar alterações'),
                  ),
                ]),
              ),
              // Segurança
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Senha atual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: _curPw, obscureText: true),
                  const SizedBox(height: 12),
                  const Text('Nova senha', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: _newPw, obscureText: true),
                  const Text('Mínimo 8 caracteres', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: (_saving || _curPw.text.isEmpty || _newPw.text.length < 8) ? null : _changePassword,
                    child: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Alterar senha'),
                  ),
                ]),
              ),
              // Assinatura
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPremium ? AppColors.primary.withOpacity(0.06) : AppColors.bgDarker,
                      border: Border.all(color: isPremium ? AppColors.primary.withOpacity(0.25) : AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${plan?.id ?? 'free'} Plan', style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800)),
                          Text(isPremium ? 'Streaming ilimitado · Sem anúncios · Downloads' : '1 hora gratuita de streaming por IP',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ]),
                      ),
                      if (!isPremium)
                        ElevatedButton(onPressed: () => context.go('/main/plans'), child: const Text('Assinar')),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/auth/login');
          },
          icon: const Icon(Icons.logout, color: AppColors.primary, size: 18),
          label: const Text('Sair', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
