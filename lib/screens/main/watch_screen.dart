import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/decrypt_proxy_server.dart';

/// WatchScreen — equivalente ao watch/[id]/page.tsx + ShakaPlayer.tsx.
///
/// Fluxo:
///   1. contentApi.getStream(id) → { drmKeyHex, masterUrl, quality, ... }
///   2. Sobe um DecryptProxyServer local que decripta os segmentos .bin
///      (ChaCha20, chunk-v2) on-the-fly
///   3. video_player/Chewie consome o master.m3u8 servido pelo proxy local
///   4. progressApi.update() periodicamente, igual ao site
class WatchScreen extends ConsumerStatefulWidget {
  final String id;
  final bool offline;
  const WatchScreen({super.key, required this.id, this.offline = false});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      // 1) Pede os detalhes de stream ao backend (equivalente a
      //    contentApi.getStream + fetchStreamMeta do ShakaPlayer.tsx).
      final stream = await contentApi.getStream(widget.id);
      final content = await contentApi.get(widget.id).catchError((_) => <String, dynamic>{});

      final keyHex = stream['drmKeyHex'] ?? stream['drm_key_hex'] ?? stream['keyHex'];
      final masterUrl = stream['masterUrl'] ?? stream['master_url'];
      _quality = stream['quality']?.toString() ?? '';
      _title = content['meta']?['title'] ?? content['title'] ?? '';

      if (keyHex == null || masterUrl == null) {
        setState(() { _error = 'Stream indisponível.'; _loading = false; });
        return;
      }

      // 2) Sobe o proxy local que decripta os segmentos .bin em tempo real.
      _proxy = DecryptProxyServer(masterUrl: masterUrl, keyHex: keyHex);
      final localUrl = await _proxy!.start();

      // 3) Inicializa o video_player apontado para o proxy local.
      _videoController = VideoPlayerController.networkUrl(Uri.parse(localUrl));
      await _videoController!.initialize();

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

      _videoController!.addListener(_onProgress);

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = 'Falha ao carregar o stream.'; _loading = false; });
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
