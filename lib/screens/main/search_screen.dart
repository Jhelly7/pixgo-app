import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/content_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<ContentItem> _results = [];
  List<String> _popular = [];
  bool _loading = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    searchApi.popular().then((p) {
      setState(() => _popular = p.map((e) => e['term'].toString()).toList());
    }).catchError((_) {});
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _total = 0; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 340), () async {
      setState(() => _loading = true);
      try {
        final res = await searchApi.search(q, {'limit': 24});
        final items = (res['results'] as List? ?? []).map((e) => ContentItem.fromJson(e)).toList();
        setState(() {
          _results = items;
          _total = res['pagination']?['total'] ?? items.length;
          _loading = false;
        });
      } catch (_) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buscar', style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar filmes, séries, anime...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.text.trim().isEmpty && _popular.isNotEmpty) ...[
          const Row(children: [
            Icon(Icons.trending_up, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text('Em alta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _popular.map((term) => ActionChip(
              label: Text(term, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppColors.cardBg,
              onPressed: () { _controller.text = term; _onChanged(term); },
            )).toList(),
          ),
        ],
        if (_controller.text.trim().isNotEmpty)
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('Nenhum resultado', style: TextStyle(color: AppColors.textMuted)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_total resultados', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.52,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (c, i) => ContentCardWidget(
                            item: _results[i],
                            onTap: () => context.go('/main/content/${_results[i].id}'),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
