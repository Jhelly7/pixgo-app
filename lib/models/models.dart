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
        id: j['id']?.toString() ?? '',
        username: j['username'] ?? '',
        name: j['name'] ?? '',
        email: j['email'],
        role: j['role'] ?? 'user',
        planId: j['plan_id'] ?? 'free',
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
        id: j['id']?.toString() ?? 'free',
        name: j['name'] ?? 'Free',
        priceBrl: (j['price_brl'] as num?)?.toDouble(),
        priceUsdt: (j['price_usdt'] as num?)?.toDouble(),
        isActive: j['is_active'] == true,
        expiresAt: j['expires_at'],
        durationDays: j['duration_days'],
      );

  static AppPlan free() => AppPlan(id: 'free', name: 'Free');
}

class Profile {
  final String id;
  final String? name;
  Profile({required this.id, this.name});
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id']?.toString() ?? '', name: j['name']);
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
      id: j['id']?.toString() ?? '',
      title: meta?['title'] ?? j['title'] ?? '—',
      poster: meta?['poster'] ?? j['poster'],
      description: meta?['description'] ?? j['description'],
      year: j['year'] is int ? j['year'] : int.tryParse('${j['year'] ?? ''}'),
      type: j['type'],
      rating: (meta?['rating'] ?? j['rating'] as num?)?.toDouble(),
      genres: ((meta?['genres'] ?? j['genres']) as List?)?.map((e) => e.toString()).toList() ?? [],
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
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? '',
        logo: j['logo'],
        group: j['group'],
        country: j['country'],
        language: j['language'],
        url: j['url'],
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
