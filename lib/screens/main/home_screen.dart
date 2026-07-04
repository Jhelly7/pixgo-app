import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/content_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<ContentItem> _featured = [];
  List<ContentItem> _movies = [];
  List<ContentItem> _series = [];
  List<ContentItem> _anime = [];
  List<ContentItem> _popular = [];
  int _heroIdx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        catalogApi.featured(6),
        catalogApi.latest('movie', 12),
        catalogApi.latest('series', 12),
        catalogApi.latest('anime', 12),
        catalogApi.list({'sort': 'popular', 'limit': 12}),
      ]);
      setState(() {
        _featured = (results[0] as List).map((e) => ContentItem.fromJson(e)).toList();
        _movies = (results[1] as List).map((e) => ContentItem.fromJson(e)).toList();
        _series = (results[2] as List).map((e) => ContentItem.fromJson(e)).toList();
        _anime = (results[3] as List).map((e) => ContentItem.fromJson(e)).toList();
        final popRes = results[4];
        final popItems = popRes is Map ? (popRes['items'] ?? []) : popRes;
        _popular = (popItems as List).map((e) => ContentItem.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final hasAny = _featured.isNotEmpty || _movies.isNotEmpty || _series.isNotEmpty || _anime.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.tv_off_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Nenhum conteúdo disponível no momento.'),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _load, child: const Text('Tentar novamente')),
        ]),
      );
    }

    final hero = _featured.isNotEmpty ? _featured[_heroIdx % _featured.length] : null;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (hero != null) _buildHero(hero),
          const SizedBox(height: 18),
          _buildRow('Em alta agora', _popular),
          _buildRow('Filmes recentes', _movies),
          _buildRow('Séries', _series),
          _buildRow('Anime', _anime),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHero(ContentItem hero) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: hero.poster != null
                ? CachedNetworkImage(imageUrl: hero.poster!, fit: BoxFit.cover)
                : Container(color: AppColors.cardBg),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(hero.type ?? '').toUpperCase()}${hero.year != null ? ' · ${hero.year}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  hero.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push('/main/watch/${hero.id}'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Assistir'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/main/content/${hero.id}'),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('Detalhes'),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, List<ContentItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (c, i) => SizedBox(
                width: 128,
                child: ContentCardWidget(
                  item: items[i],
                  onTap: () => context.go('/main/content/${items[i].id}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
