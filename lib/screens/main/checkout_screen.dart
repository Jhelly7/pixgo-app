import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String planType;
  const CheckoutScreen({super.key, required this.planType});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Status { idle, creating, pending, confirmed, alreadyActive, expired, error }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Map<String, dynamic>? _payment;
  _Status _status = _Status.idle;
  int _timeLeft = 0;
  Timer? _countdown;
  Timer? _poll;
  String? _activeUntil;
  double? _rate;

  @override
  void initState() {
    super.initState();
    paymentsApi.convert().then((r) => setState(() => _rate = (r['rate'] as num?)?.toDouble())).catchError((_) {});
    _create();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _status = _Status.creating);
    try {
      final res = await paymentsApi.create({'plan_type': widget.planType});
      if (res['status'] == 'confirmed') {
        setState(() => _status = _Status.confirmed);
        ref.read(authProvider.notifier).refreshMe();
        return;
      }
      setState(() {
        _payment = res;
        _status = _Status.pending;
      });
      _startCountdown(res['expires_at']);
      _startPolling(res['payment_id']);
    } on ApiException catch (e) {
      if (e.status == 409) {
        setState(() {
          _activeUntil = e.data?['expires_at'];
          _status = _Status.alreadyActive;
        });
      } else {
        setState(() => _status = _Status.error);
      }
    } catch (_) {
      setState(() => _status = _Status.error);
    }
  }

  void _startCountdown(String? expiresAt) {
    if (expiresAt == null) return;
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return;
    void tick() {
      final secs = exp.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      setState(() => _timeLeft = secs > 0 ? secs : 0);
      if (secs <= 0) {
        _countdown?.cancel();
        setState(() => _status = _Status.expired);
      }
    }
    tick();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startPolling(String? paymentId) {
    if (paymentId == null) return;
    _poll = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final s = await paymentsApi.status(paymentId);
        if (s['status'] == 'confirmed') {
          _poll?.cancel();
          _countdown?.cancel();
          setState(() => _status = _Status.confirmed);
          ref.read(authProvider.notifier).refreshMe();
        } else if (s['status'] == 'expired' || s['status'] == 'failed') {
          _poll?.cancel();
          setState(() => _status = _Status.expired);
        }
      } catch (_) {}
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado!'), duration: Duration(seconds: 1)));
  }

  String _fmtTime(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Finalizar assinatura')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: _body())),
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.idle:
      case _Status.creating:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));

      case _Status.alreadyActive:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, color: AppColors.secondary, size: 48),
            const SizedBox(height: 12),
            const Text('Você já tem uma assinatura ativa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (_activeUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Válido até ${_activeUntil!.substring(0, 10)}', style: const TextStyle(color: AppColors.textMuted)),
              ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => context.go('/main'), child: const Text('Voltar ao início')),
          ]),
        );

      case _Status.confirmed:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium, color: AppColors.secondary, size: 52),
            const SizedBox(height: 14),
            const Text('Você agora é Premium!', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Pagamento confirmado. Aproveite streaming ilimitado.', style: TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => context.go('/main'), child: const Text('Começar a assistir')),
          ]),
        );

      case _Status.expired:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.timer_off, color: AppColors.primary, size: 44),
            const SizedBox(height: 12),
            const Text('Pagamento expirado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('O prazo de pagamento expirou. Gere um novo pedido.', style: TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _create, child: const Text('Novo pedido')),
          ]),
        );

      case _Status.error:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppColors.primary, size: 44),
            const SizedBox(height: 12),
            const Text('Erro ao criar pagamento'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _create, child: const Text('Tentar novamente')),
          ]),
        );

      case _Status.pending:
        final address = _payment?['address']?.toString() ?? '';
        final amount = _payment?['amount_usdt']?.toString() ?? '';
        final planName = _payment?['plan_name']?.toString() ?? 'USDT';
        final brl = _rate != null && amount.isNotEmpty
            ? (double.tryParse(amount) ?? 0) * _rate!
            : null;

        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pague com USDT na rede Polygon — rápido, seguro, sem intermediários.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(planName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text('Expira em ${_fmtTime(_timeLeft)}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 16),
                if (address.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: QrImageView(data: address, size: 180),
                  ),
                const SizedBox(height: 16),
                const Text('Valor exato', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Text('$amount USDT', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                if (brl != null) Text('≈ R\$ ${brl.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                const Text('Endereço Polygon', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _copy(address),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.bgDarker, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Expanded(child: Text(address, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Expanded(child: Text('Importante: selecione a rede Polygon (PoS) ao enviar.', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            const Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              SizedBox(width: 8),
              Text('Aguardando confirmação na blockchain...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 20),
            const Text('Como pagar', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _step(1, 'Baixe um app de exchange (Binance, Bybit, MEXC...)'),
            _step(2, 'Cadastre-se gratuitamente'),
            _step(3, 'Compre $amount USDT usando PIX ou cartão'),
            _step(4, 'Envie para o endereço Polygon acima, na rede Polygon (PoS)'),
          ]),
        );
    }
  }

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 11, backgroundColor: AppColors.primary, child: Text('$n', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
        ]),
      );
}
