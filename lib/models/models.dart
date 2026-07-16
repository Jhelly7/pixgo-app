/// Sanitiza valores de string vindos da API: trata null, string vazia, e as
/// strings literais "undefined"/"null" (que por vezes vêm assim mesmo do
/// backend) como "sem valor" — evita que "undefined" apareça escrito nos ecrãs.
String? cleanStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (lower == 'undefined' || lower == 'null') return null;
  return s;
}

class AppUser {
  final String id;
  final String username;
  final String name;
  final String? email;
  final String role;
  final String planId;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    required this.role,
    required this.planId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: cleanStr(j['id']) ?? '',
        username: cleanStr(j['username']) ?? '',
        name: cleanStr(j['name']) ?? '',
        email: cleanStr(j['email']),
        role: cleanStr(j['role']) ?? 'user',
        planId: cleanStr(j['plan_id']) ?? 'free',
      );
}

class AppPlan {
  final String id;
  final String name;
  final double? priceBrl;
  final double? priceUsdt;
  final bool isActive;
  final String? expiresAt;
  final int? durationDays;

  AppPlan({
    required this.id,
    required this.name,
    this.priceBrl,
    this.priceUsdt,
    this.isActive = false,
    this.expiresAt,
    this.durationDays,
  });

  factory AppPlan.fromJson(Map<String, dynamic> j) => AppPlan(
        id: cleanStr(j['id']) ?? 'free',
        name: cleanStr(j['name']) ?? 'Free',
        priceBrl: (j['price_brl'] as num?)?.toDouble(),
        priceUsdt: (j['price_usdt'] as num?)?.toDouble(),
        isActive: j['is_active'] == true,
        expiresAt: cleanStr(j['expires_at']),
        durationDays: j['duration_days'] is int ? j['duration_days'] : int.tryParse('${j['duration_days'] ?? ''}'),
      );

  static AppPlan free() => AppPlan(id: 'free', name: 'Free');
}

class Profile {
  final String id;
  final String? name;
  Profile({required this.id, this.name});
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: cleanStr(j['id']) ?? '', name: cleanStr(j['name']));
}

class ContentItem {
  final String id;
  final String title;
  final String? poster;
  final String? description;
  final int? year;
  final String? type;
  final double? rating;
  final List<String> genres;
  final double? progress;

  ContentItem({
    required this.id,
    required this.title,
    this.poster,
    this.description,
    this.year,
    this.type,
    this.rating,
    this.genres = const [],
    this.progress,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] as Map<String, dynamic>?;
    return ContentItem(
      id: cleanStr(j['id']) ?? '',
      title: cleanStr(meta?['title']) ?? cleanStr(j['title']) ?? '—',
      poster: cleanStr(meta?['poster']) ?? cleanStr(j['poster']),
      description: cleanStr(meta?['description']) ?? cleanStr(j['description']),
      year: j['year'] is int ? j['year'] as int : int.tryParse(cleanStr(j['year']) ?? ''),
      type: cleanStr(j['type']),
      rating: (meta?['rating'] as num?)?.toDouble() ?? (j['rating'] as num?)?.toDouble(),
      genres: ((meta?['genres'] ?? j['genres']) as List?)
              ?.map((e) => cleanStr(e))
              .whereType<String>()
              .toList() ??
          [],
      progress: (j['progress'] as num?)?.toDouble(),
    );
  }
}

class ChannelItem {
  final String id;
  final String name;
  final String? logo;
  final String? group;
  final String? country;
  final String? language;
  final String? url;
  final bool hasAccess;
  final bool locked;

  ChannelItem({
    required this.id,
    required this.name,
    this.logo,
    this.group,
    this.country,
    this.language,
    this.url,
    this.hasAccess = false,
    this.locked = true,
  });

  factory ChannelItem.fromJson(Map<String, dynamic> j) => ChannelItem(
        id: cleanStr(j['id']) ?? '',
        name: cleanStr(j['name']) ?? '',
        logo: cleanStr(j['logo']),
        group: cleanStr(j['group']),
        country: cleanStr(j['country']),
        language: cleanStr(j['language']),
        url: cleanStr(j['url']),
        hasAccess: j['has_access'] == true,
        locked: j['locked'] == true,
      );
}

class DownloadItem {
  final String contentId;
  final String title;
  final String? poster;
  final String quality;
  final DateTime expiresAt;

  DownloadItem({
    required this.contentId,
    required this.title,
    this.poster,
    required this.quality,
    required this.expiresAt,
  });
}
