import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _loading = true;
  List<ChannelItem> _channels = [];
  String _filter = 'All';
  final _categories = ['All', 'PT', 'ES', 'EN', 'News', 'Sports', 'Anime', 'Musica', 'Infantil', 'Filmes'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await channelsApi.list();
      final list = (res['channels'] as List? ?? []).map((e) => ChannelItem.fromJson(e)).toList();
      setState(() { _channels = list; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _channels
        : _channels.where((c) =>
            (c.group ?? '').toLowerCase().contains(_filter.toLowerCase()) ||
            (c.language ?? '').toLowerCase().contains(_filter.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.live_tv_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TV ao Vivo', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${_channels.length} canais disponíveis', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (c, i) {
              final cat = _categories[i];
              final active = _filter == cat;
              return ChoiceChip(
                label: Text(cat, style: const TextStyle(fontSize: 11)),
                selected: active,
                onSelected: (_) => setState(() => _filter = cat),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.cardBg,
                labelStyle: TextStyle(color: active ? Colors.white : AppColors.textMuted),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? const Center(child: Text('Nenhum canal encontrado nesta categoria.', style: TextStyle(color: AppColors.textMuted)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.7,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final ch = filtered[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (ch.locked) {
                              context.go('/main/plans');
                            } else {
                              context.push('/main/watch/channel_${ch.id}');
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ch.logo != null
                                    ? CachedNetworkImage(imageUrl: ch.logo!, width: 40, height: 40, fit: BoxFit.cover,
                                        errorWidget: (c, u, e) => const Icon(Icons.tv, color: AppColors.textMuted))
                                    : const Icon(Icons.tv, color: AppColors.textMuted, size: 30),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
                                      child: const Text('AO VIVO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ),
                                    if (ch.locked) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.lock, size: 12, color: AppColors.textMuted),
                                    ],
                                  ]),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
