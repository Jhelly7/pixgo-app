import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../core/chacha20.dart';

/// decrypt_proxy_server.dart
///
/// O site original usa hls.js com um "bin loader" custom (ShakaPlayer.tsx)
/// que intercepta pedidos .bin (init.bin e seg00001.bin, seg00002.bin, ...),
/// decripta-os via Web Worker ChaCha20, e entrega o fMP4 plaintext ao MSE.
///
/// O Flutter/video_player (ExoPlayer no Android) não tem equivalente a MSE
/// custom loaders. A solução adoptada aqui é um servidor HTTP local
/// (127.0.0.1:porta_aleatória) que:
///   1. Serve um master.m3u8 reescrito (URIs .bin apontam para este proxy)
///   2. Em cada pedido de segmento, busca o .bin remoto original, decripta
///      com ChaCha20 (chunk-v2, igual ao worker JS) e devolve o fMP4 puro
///   3. video_player/ExoPlayer consome http://127.0.0.1:porta/master.m3u8
///      como se fosse um HLS normal, sem saber que existe encriptação.
///
/// Contrato esperado de contentApi.getStream(id) (ver ShakaPlayer.tsx):
///   { drmKeyHex, masterUrl, noncesUrl?, segExt: 'bin' | 'ts', quality }
class DecryptProxyServer {
  DecryptProxyServer({
    required this.masterUrl,
    required this.keyHex,
  });

  final String masterUrl;
  final String keyHex;

  HttpServer? _server;
  final _client = http.Client();

  /// Cache em memória do master.m3u8 já reescrito (pouco custo, ficheiro pequeno).
  String? _rewrittenPlaylist;
  Uri? _baseUri;

  /// Sobe o servidor local e devolve a URL do master.m3u8 pronta a usar
  /// no VideoPlayerController (ex: http://127.0.0.1:PORT/master.m3u8).
  Future<String> start() async {
    final handler = const Pipeline().addHandler(_handleRequest);
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    return 'http://127.0.0.1:${_server!.port}/master.m3u8';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _client.close();
  }

  Future<Response> _handleRequest(Request request) async {
    try {
      if (request.url.path == 'master.m3u8') {
        return await _servePlaylist();
      }
      if (request.url.path == 'seg') {
        final target = request.url.queryParameters['u'];
        if (target == null) return Response.badRequest(body: 'missing u');
        return await _serveSegment(target);
      }
      return Response.notFound('not found');
    } catch (e) {
      return Response.internalServerError(body: 'proxy error: $e');
    }
  }

  Future<Response> _servePlaylist() async {
    if (_rewrittenPlaylist != null) {
      return Response.ok(_rewrittenPlaylist, headers: {'content-type': 'application/vnd.apple.mpegurl'});
    }

    final res = await _client.get(Uri.parse(masterUrl));
    if (res.statusCode != 200) {
      return Response.internalServerError(body: 'failed to fetch master playlist (${res.statusCode})');
    }

    _baseUri = Uri.parse(masterUrl);
    final lines = const LineSplitter().convert(res.body);
    final out = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('#EXT-X-MAP')) {
        // #EXT-X-MAP:URI="init.bin"  →  reescreve URI para o proxy local
        final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
        if (match != null) {
          final original = _resolve(match.group(1)!);
          final proxied = '/seg?u=${Uri.encodeQueryComponent(original)}';
          out.writeln(line.replaceFirst(match.group(0)!, 'URI="$proxied"'));
          continue;
        }
        out.writeln(line);
        continue;
      }

      if (line.isNotEmpty && !line.startsWith('#')) {
        // Linha de segmento (.bin, .ts, ou sub-playlist .m3u8)
        final original = _resolve(line.trim());
        if (original.endsWith('.m3u8')) {
          // Master multi-qualidade: aponta a sub-playlist para o próprio
          // proxy também, para que os segmentos dela passem por aqui.
          out.writeln('/subplaylist?u=${Uri.encodeQueryComponent(original)}');
        } else {
          out.writeln('/seg?u=${Uri.encodeQueryComponent(original)}');
        }
        continue;
      }

      out.writeln(line);
    }

    _rewrittenPlaylist = out.toString();
    return Response.ok(_rewrittenPlaylist, headers: {'content-type': 'application/vnd.apple.mpegurl'});
  }

  String _resolve(String maybeRelative) {
    if (maybeRelative.startsWith('http://') || maybeRelative.startsWith('https://')) {
      return maybeRelative;
    }
    final base = _baseUri ?? Uri.parse(masterUrl);
    return base.resolve(maybeRelative).toString();
  }

  Future<Response> _serveSegment(String originalUrl) async {
    final res = await _client.get(Uri.parse(originalUrl));
    if (res.statusCode != 200) {
      return Response.internalServerError(body: 'failed to fetch segment (${res.statusCode})');
    }

    final raw = res.bodyBytes;
    final isEncrypted = originalUrl.endsWith('.bin');

    final plaintext = isEncrypted ? ChaCha20.decryptSegment(raw, keyHex) : raw;

    return Response.ok(
      plaintext,
      headers: {
        'content-type': 'video/mp4',
        'cache-control': 'no-store',
      },
    );
  }
}
