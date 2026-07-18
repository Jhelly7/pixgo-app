import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/ecdh.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/decrypt_proxy_server.dart';

/// WatchScreen — equivalente ao watch/[id]/page.tsx + ShakaPlayer.tsx PARA
/// VOD, e ao ChannelPlayer.tsx para TV ao vivo.
///
/// IMPORTANTE: canais ao vivo e VOD usam pipelines COMPLETAMENTE diferentes
/// no backend (confirmado em routes/channels.js):
///   - Canal: GET /api/channels/:id → { url, ... } — HLS *simples*, sem
///     encriptação, sem handshake. Tentar passar isto pelo pipeline de VOD
///     (ECDH + ChaCha20 + proxy local) falha sempre — era a causa de
///     "falha ao carregar stream" em TODOS os canais.
///   - VOD: GET /api/content/:id/stream?clientPubKey=... →
///     { drm_key_hex, master_url, ... } — precisa do proxy de decriptação.
class WatchScreen extends ConsumerStatefulWidget {
  final String id;
  final bool offline;
  final String? episodeId;
  const WatchScreen({super.key, required this.id, this.offline = false, this.episodeId});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  DecryptProxyServer? _proxy;

  bool _loading = true;
  String? _error;
  String _quality = '';
  String _title = '';
  bool get _isChannel => widget.id.startsWith('channel_');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      if (_isChannel) {
        await _initChannel();
      } else {
        await _initVod();
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.status == 429
            ? 'Limite gratuito de 1 hora atingido. Assine um plano para continuar.'
            : (e.status == 401
                ? 'Faça login para assistir.'
                : (e.status == 404
                    ? 'Conteúdo não encontrado.'
                    : 'Falha ao carregar o stream.'));
        _loading = false;
      });
      if (kDebugMode) debugPrint('WatchScreen ApiException: ${e.status} ${e.message}');
    } catch (e, st) {
      setState(() { _error = 'Falha ao carregar o stream.'; _loading = false; });
      if (kDebugMode) debugPrint('WatchScreen error: $e\n$st');
    }
  }

  /// TV ao vivo — URL direta, sem decriptação nenhuma.
  Future<void> _initChannel() async {
    final realId = widget.id.substring('channel_'.length);
    final ch = await channelsApi.get(realId);

    final url = cleanStr(ch['url']);
    _title = cleanStr(ch['name']) ?? '';

    if (url == null) {
      setState(() { _error = 'Canal indisponível.'; _loading = false; });
      return;
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController!.initialize();
    await _setupChewie();
    setState(() => _loading = false);
  }

  /// VOD (filmes/séries) — handshake ECDH + proxy de decriptação ChaCha20.
  Future<void> _initVod() async {
    final clientPubKey = Ecdh.generateClientPubKeyBase64();

    final params = <String, dynamic>{'clientPubKey': clientPubKey};
    if (widget.episodeId != null) params['episode'] = widget.episodeId;

    final stream = await contentApi.getStream(widget.id, params);
    final content = await contentApi.get(widget.id).catchError((_) => <String, dynamic>{});

    final keyHex = stream['drm_key_hex'] ?? stream['drmKeyHex'];
    final masterUrl = stream['master_url'] ?? stream['url'] ?? stream['masterUrl'];
    _quality = cleanStr(stream['quality']) ?? '';
    final meta = content['meta'];
    _title = cleanStr(meta is Map ? meta['title'] : null) ??
        cleanStr(content['title']) ??
        cleanStr(meta is Map ? meta['name'] : null) ??
        cleanStr(content['name']) ??
        '';

    if (keyHex == null || masterUrl == null) {
      setState(() { _error = 'Stream indisponível.'; _loading = false; });
      return;
    }

    _proxy = DecryptProxyServer(masterUrl: masterUrl, keyHex: keyHex);
    final localUrl = await _proxy!.start();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(localUrl));
    await _videoController!.initialize();
    await _setupChewie();
    setState(() => _loading = false);
  }

  Future<void> _setupChewie() async {
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary,
        bufferedColor: Colors.white24,
        backgroundColor: Colors.white10,
      ),
    );
    if (!_isChannel) {
      _videoController!.addListener(_onProgress);
    }
  }

  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);

  void _onProgress() {
    final v = _videoController;
    if (v == null || !v.value.isInitialized) return;
    final now = DateTime.now();
    if (now.difference(_lastProgressSave).inSeconds < 15) return;
    _lastProgressSave = now;

    final profiles = ref.read(authProvider).profiles;
    if (profiles.isEmpty) return;
    final durationSecs = v.value.duration.inSeconds;
    if (durationSecs == 0) return;
    final pct = (v.value.position.inSeconds / durationSecs) * 100;

    progressApi.update(
      profileId: profiles.first.id,
      contentId: widget.id,
      progress: pct,
      duration: durationSecs,
    ).catchError((_) {});
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onProgress);
    _chewieController?.dispose();
    _videoController?.dispose();
    _proxy?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: AppColors.primary, size: 40),
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
                    ]),
                  )
                : Stack(children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio == 0 ? 16 / 9 : _videoController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                    Positioned(
                      top: 8, left: 8,
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (_title.isNotEmpty)
                          Flexible(
                            child: Text(_title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                      ]),
                    ),
                    if (_quality.isNotEmpty)
                      Positioned(
                        top: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: Text(_quality, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                        ),
                      ),
                  ]),
      ),
    );
  }
}
