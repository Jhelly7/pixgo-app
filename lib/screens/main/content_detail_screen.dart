import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ContentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  Map<String, dynamic>? _content;
  bool _loading = true;
  bool _inList = false;
  int _openSeason = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await contentApi.get(widget.id);
      setState(() { _content = c; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleList() async {
    final profiles = ref.read(authProvider).profiles;
    if (profiles.isEmpty) return;
    try {
      if (_inList) {
        await myListApi.remove(profiles.first.id, widget.id);
      } else {
        await myListApi.add(profiles.first.id, widget.id);
      }
      setState(() => _inList = !_inList);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bgDark, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_content == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(),
        body: const Center(child: Text('Conteúdo não encontrado', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final c = _content!;
    final meta = c['meta'] as Map<String, dynamic>? ?? {};
    final title = cleanStr(meta['title']) ?? cleanStr(c['title']) ?? cleanStr(meta['name']) ?? cleanStr(c['name']) ?? '';
    final poster = cleanStr(meta['poster']) ?? cleanStr(c['poster']);
    final desc = cleanStr(meta['description']) ?? cleanStr(c['description']) ?? '';
    final genres = ((meta['genres'] ?? c['genres']) as List?)?.cast<String>() ?? [];
    final year = cleanStr(c['year']);
    final type = cleanStr(c['type']) ?? '';
    final seasons = (c['seasons'] as List?) ?? [];
    final isEpisodic = seasons.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.bgDarker,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                if (poster != null)
                  CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
                else
                  Container(color: AppColors.cardBg),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [AppColors.bgDark, Colors.transparent],
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              Text(title, style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [
                if (year != null) Text('$year', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (year != null) const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.forType(type).withOpacity(0.18), borderRadius: BorderRadius.circular(4)),
                  child: Text(type, style: TextStyle(fontSize: 10, color: AppColors.forType(type), fontWeight: FontWeight.w700)),
                ),
              ]),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: genres.take(3).map((g) => Chip(
                  label: Text(g, style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppColors.cardBg,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )).toList()),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/main/watch/${widget.id}'),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Assistir'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _toggleList,
                  icon: Icon(_inList ? Icons.bookmark : Icons.bookmark_border, size: 18),
                  label: Text(_inList ? 'Na lista' : 'Minha Lista'),
                ),
              ]),
              const SizedBox(height: 20),
              const Text('Sobre', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
              if (isEpisodic) ...[
                const SizedBox(height: 22),
                const Text('Temporadas e Episódios', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                ...List.generate(seasons.length, (si) {
                  final season = seasons[si] as Map<String, dynamic>;
                  final episodes = (season['episodes'] as List?) ?? [];
                  final open = _openSeason == si;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(children: [
                      InkWell(
                        onTap: () => setState(() => _openSeason = open ? -1 : si),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Temporada ${si + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Row(children: [
                              Text('${episodes.length} episódios', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              Icon(open ? Icons.expand_less : Icons.chevron_right, size: 18),
                            ]),
                          ]),
                        ),
                      ),
                      if (open)
                        ...episodes.map((ep) {
                          final epMap = ep as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            title: Text(epMap['title'] ?? 'Episódio', style: const TextStyle(fontSize: 12.5)),
                            leading: const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 22),
                            onTap: () => context.push('/main/watch/${widget.id}?ep=${epMap['id']}'),
                          );
                        }),
                    ]),
                  );
                }),
              ],
            ])),
          ),
        ],
      ),
    );
  }
}
