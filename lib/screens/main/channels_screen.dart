import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

/// ChannelsScreen — réplica fiel de app/main/channels/page.tsx (técnica
/// comprovada e já testada no site, NÃO uma reinvenção client-side):
///   - Categorias vêm de channelsApi.categories() (name/slug/count reais)
///   - Filtro de categoria e paginação são feitos NO SERVIDOR
///     (channelsApi.list({page, limit, category})), nunca client-side
///   - Canais "prioritários" (palavras-chave fixas) vão para o topo da
///     lista, exatamente como sortByPriority()/PRIORITY_KEYWORDS no site
///   - A busca usa channelsApi.search() (endpoint dedicado de canais),
///     NÃO o searchApi genérico de conteúdo
///   - res.loading === true → retry automático com res.retry_ms
const _limit = 30;
const _priorityKeywords = ['record', 'geek', 'portu', 'lego', 'naruto', 'bbc', 'fifa'];

bool _isPriority(String name) =>
    _priorityKeywords.any((kw) => name.toLowerCase().contains(kw));

List<ChannelItem> _sortByPriority(List<ChannelItem> list) {
  final sorted = [...list];
  sorted.sort((a, b) {
    final pa = _isPriority(a.name) ? 0 : 1;
    final pb = _isPriority(b.name) ? 0 : 1;
    return pa - pb;
  });
  return sorted;
}

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});
  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  List<ChannelItem> _channels = [];
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _retrying = false;
  bool _searching = false;
  String _search = '';
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];

  List<ChannelItem> _priorityChannels = [];
  List<ChannelItem> _regularChannels = [];

  bool _disposed = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initialize();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await channelsApi.categories();
      if (_disposed) return;
      setState(() {
        _categories = cats.map((c) => {
              'name': cleanStr(c['name']) ?? '',
              'slug': cleanStr(c['slug']) ?? '',
              'count': c['count'] ?? 0,
            }).toList();
      });
    } catch (_) {
      // categorias são opcionais na UI — sem elas o dropdown só não aparece
    }
  }

  Future<void> _initialize() async {
    setState(() { _loading = true; _page = 1; _search = ''; _searchController.clear(); });
    await Future.wait([_loadPriorityChannels(), _loadRegularChannels(1)]);
    if (_disposed) return;
    setState(() {
      _channels = _mergeAndDisplay(1);
      _loading = false;
    });
  }

  List<ChannelItem> _mergeAndDisplay(int page) {
    if (page == 1) {
      final priorityIds = _priorityChannels.map((c) => c.id).toSet();
      final filteredRegular = _regularChannels.where((c) => !priorityIds.contains(c.id)).toList();
      return [..._priorityChannels, ...filteredRegular];
    }
    return _regularChannels;
  }

  // Prioridade não se aplica quando há filtro de categoria — igual ao site.
  Future<void> _loadPriorityChannels() async {
    if (_selectedCategory != null) { _priorityChannels = []; return; }
    try {
      final results = await Future.wait(_priorityKeywords.map((kw) =>
          channelsApi.search(kw).catchError((_) => <String, dynamic>{'channels': []})));
      final seen = <String>{};
      final list = <ChannelItem>[];
      for (final r in results) {
        for (final raw in (r['channels'] as List? ?? [])) {
          final ch = ChannelItem.fromJson(raw);
          if (!seen.contains(ch.id)) { seen.add(ch.id); list.add(ch); }
        }
      }
      _priorityChannels = list;
    } catch (_) {
      _priorityChannels = [];
    }
  }

  Future<void> _loadRegularChannels(int page) async {
    try {
      final params = <String, dynamic>{'page': page, 'limit': _limit};
      if (_selectedCategory != null) params['category'] = _selectedCategory;

      final res = await channelsApi.list(params);
      if (_disposed) return;

      if (res['loading'] == true) {
        setState(() => _retrying = true);
        final retryMs = (res['retry_ms'] as num?)?.toInt() ?? 2000;
        await Future.delayed(Duration(milliseconds: retryMs));
        if (!_disposed) await _loadRegularChannels(page);
        return;
      }

      _regularChannels = (res['channels'] as List? ?? []).map((e) => ChannelItem.fromJson(e)).toList();
      if (_disposed) return;
      setState(() {
        _total = res['pagination']?['total'] ?? _regularChannels.length;
        _totalPages = res['pagination']?['pages'] ?? 1;
        _retrying = false;
      });
    } catch (_) {
      // erro de rede — mantém o que já estava, igual ao site (toast lá,
      // aqui apenas não bloqueia a UI)
    }
  }

  Future<void> _onCategoryChanged(String? slug) async {
    setState(() => _selectedCategory = slug);
    await _initialize();
  }

  Future<void> _goToPage(int page) async {
    if (page == _page || page < 1 || page > _totalPages) return;
    setState(() { _page = page; _loading = true; });
    await _loadRegularChannels(page);
    if (_disposed) return;
    setState(() {
      _channels = _mergeAndDisplay(page);
      _loading = false;
    });
  }

  DateTime _lastSearchInput = DateTime.now();
  Future<void> _onSearchChanged(String q) async {
    _search = q;
    setState(() {});
    final now = DateTime.now();
    _lastSearchInput = now;
    if (q.trim().isEmpty) {
      setState(() => _channels = _mergeAndDisplay(_page));
      return;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (_lastSearchInput != now || _disposed) return; // debounce

    setState(() => _searching = true);
    try {
      final res = await channelsApi.search(q.trim());
      if (_disposed) return;
      setState(() {
        _channels = (res['channels'] as List? ?? []).map((e) => ChannelItem.fromJson(e)).toList();
        _total = res['total'] ?? _channels.length;
        _totalPages = 1;
      });
    } catch (_) {
    } finally {
      if (!_disposed) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() { _search = ''; _channels = _mergeAndDisplay(_page); });
  }

  Future<void> _onChannelTap(ChannelItem ch) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) { context.go('/auth/login'); return; }
    if (ch.locked || !ch.hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canal premium. Assine para assistir.')));
      return;
    }
    context.push('/main/watch/channel_${ch.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _channels.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.live_tv_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('channels.title'), style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              '$_total ${context.t('channels.available')}${_selectedCategory != null ? ' · $_selectedCategory' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar canais...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                    : (_search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _clearSearch)
                        : null),
              ),
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CategoryDropdown(
              categories: _categories,
              selected: _selectedCategory,
              onChanged: _onCategoryChanged,
            ),
          ],
        ]),
        const SizedBox(height: 14),
        if (_retrying)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Column(children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 10),
              Text('Carregando canais...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
          ),
        Expanded(
          child: _channels.isEmpty && !_retrying
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.live_tv_outlined, size: 32, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text(_search.isNotEmpty ? 'Nenhum canal encontrado' : 'Nenhum canal disponível',
                        style: const TextStyle(color: AppColors.textMuted)),
                    if (_search.isNotEmpty || _selectedCategory != null)
                      TextButton(
                        onPressed: () { _clearSearch(); _onCategoryChanged(null); },
                        child: const Text('Limpar filtros'),
                      ),
                  ]),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _sortByPriorityCached.length,
                  itemBuilder: (c, i) {
                    final ch = _sortByPriorityCached[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _onChannelTap(ch),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ch.logo != null
                                ? CachedNetworkImage(
                                    imageUrl: ch.logo!,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) => Container(color: AppColors.cardHover),
                                    placeholder: (c, u) => Container(color: AppColors.cardBg),
                                  )
                                : Container(
                                    decoration: BoxDecoration(color: AppColors.cardHover, borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.live_tv, color: AppColors.textMuted, size: 28),
                                  ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10, right: 10, bottom: 8,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                              if (ch.group != null)
                                Text(ch.group!, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.65))),
                            ]),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: ch.locked
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.lock, size: 10, color: AppColors.textMuted),
                                      SizedBox(width: 3),
                                      Text('Premium', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                    ]),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('AO VIVO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_search.isEmpty && _totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: _page > 1 ? () => _goToPage(_page - 1) : null, icon: const Icon(Icons.chevron_left)),
              Text('Pág. $_page / $_totalPages', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              IconButton(onPressed: _page < _totalPages ? () => _goToPage(_page + 1) : null, icon: const Icon(Icons.chevron_right)),
            ]),
          ),
      ],
    );
  }

  List<ChannelItem> get _sortByPriorityCached => _search.isEmpty ? _sortByPriority(_channels) : _channels;
}

class _CategoryDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({required this.categories, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selectedName = selected == null
        ? 'Todas as categorias'
        : (categories.firstWhere((c) => c['slug'] == selected, orElse: () => {'name': selected})['name'] as String);

    return PopupMenuButton<String?>(
      onSelected: onChanged,
      itemBuilder: (c) => [
        const PopupMenuItem(value: null, child: Text('Todas as categorias')),
        const PopupMenuDivider(),
        ...categories.map((cat) => PopupMenuItem(
              value: cat['slug'] as String,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text(cat['name'] as String, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('${cat['count']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            )),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.live_tv, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(selectedName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
