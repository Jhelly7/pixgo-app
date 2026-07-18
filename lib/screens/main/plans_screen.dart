import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

const _screensByPlan = {'weekly': 4, 'monthly': 6, 'annual': 10};

const _featuresByPlan = {
  'weekly': [
    'Streaming ilimitado por 7 dias',
    'TV ao vivo',
    'Até 4 telas simultâneas',
    'Qualidade HD',
  ],
  'monthly': [
    'Streaming ilimitado por 30 dias',
    'TV ao vivo',
    'Até 6 telas simultâneas',
    'Qualidade HD e Full HD',
    'Download para assistir offline',
  ],
  'annual': [
    'Streaming ilimitado por 365 dias',
    'TV ao vivo',
    'Até 10 telas simultâneas',
    'Qualidade HD, Full HD e 4K',
    'Download para assistir offline',
    'Melhor custo-benefício',
  ],
};

String _planType(int? durationDays) {
  final d = durationDays ?? 30;
  if (d <= 7) return 'weekly';
  if (d <= 31) return 'monthly';
  return 'annual';
}

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});
  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  bool _loading = true;
  List<dynamic> _plans = [];
  double? _rate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([paymentsApi.plans(), paymentsApi.convert()]);
      setState(() {
        _plans = results[0] as List;
        _rate = (results[1] as Map)['rate']?.toDouble();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(authProvider).plan;
    final isPremium = plan != null && plan.id != 'free';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('plans.title'), style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(context.t('plans.subtitle'), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          if (isPremium)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.check, color: AppColors.secondary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Você já tem o plano ${plan.name} ativo.', style: const TextStyle(fontSize: 13))),
              ]),
            ),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
          else
            ..._plans.map((p) {
              final type = _planType(p['duration_days']);
              final screens = _screensByPlan[type] ?? 4;
              final features = _featuresByPlan[type] ?? [];
              final usdt = (p['price_usdt'] as num?)?.toDouble() ?? 0;
              final brl = _rate != null ? (usdt * _rate!).toStringAsFixed(2).replaceAll('.', ',') : '—';
              final periodLabel = type == 'weekly' ? 'semana' : type == 'monthly' ? 'mês' : 'ano';
              final isPopular = type == 'monthly';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPopular ? AppColors.primary.withOpacity(0.4) : AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cleanStr(p['name']) ?? '', style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('R\$ $brl', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                      Text('/$periodLabel', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                    Text('$usdt USDT · Polygon', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Icon(Icons.check, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
                          ]),
                        )),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('$screens telas simultâneas', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/main/plans/checkout?plan=$type'),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: Text(context.t('plans.payUsdt')),
                      ),
                    ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
