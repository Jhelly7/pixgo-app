import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// api_client.dart — equivalente Dart de lib/api.ts + a lógica authedFetch de
/// store/auth.ts. Faz refresh automático do token em 401 e repete o pedido
/// uma única vez (mesmo comportamento do frontend original).
const String kApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.pixgo.frii.site',
);

const _kTokenKey = 'pixgo_token';
const _kRefreshKey = 'pixgo_refresh';

class ApiException implements Exception {
  final int? status;
  final String message;
  final dynamic data;
  ApiException(this.message, {this.status, this.data});
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: '$kApiBase/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Future<String?> get token async => _storage.read(key: _kTokenKey);
  Future<String?> get refreshToken async => _storage.read(key: _kRefreshKey);

  Future<void> setTokens({required String token, String? refresh}) async {
    await _storage.write(key: _kTokenKey, value: token);
    if (refresh != null) await _storage.write(key: _kRefreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kRefreshKey);
  }

  bool _refreshing = false;

  Future<String?> _doRefresh() async {
    final rt = await refreshToken;
    if (rt == null) return null;
    try {
      final res = await Dio(BaseOptions(baseUrl: kApiBase)).post(
        '/api/auth/refresh',
        data: {'refresh_token': rt},
      );
      final newToken = res.data['token'] as String?;
      final newRefresh = res.data['refresh_token'] as String?;
      if (newToken != null) {
        await setTokens(token: newToken, refresh: newRefresh);
        return newToken;
      }
      return null;
    } catch (_) {
      await clearTokens();
      return null;
    }
  }

  Future<dynamic> _req(String method, String path, {dynamic data}) async {
    final t = await token;
    final opts = Options(method: method, headers: {
      if (t != null) 'Authorization': 'Bearer $t',
    });

    try {
      final res = await _dio.request(path, data: data, options: opts);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final newToken = await _doRefresh();
        if (newToken == null) {
          throw ApiException('Sessão expirada', status: 401, data: e.response?.data);
        }
        final retryOpts = Options(method: method, headers: {'Authorization': 'Bearer $newToken'});
        try {
          final res2 = await _dio.request(path, data: data, options: retryOpts);
          return res2.data;
        } on DioException catch (e2) {
          throw ApiException(
            e2.response?.data?['message'] ?? e2.message ?? 'Request failed',
            status: e2.response?.statusCode,
            data: e2.response?.data,
          );
        }
      }
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Request failed',
        status: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<dynamic> get(String path) => _req('GET', path);
  Future<dynamic> post(String path, [dynamic data]) => _req('POST', path, data: data);
  Future<dynamic> put(String path, [dynamic data]) => _req('PUT', path, data: data);
  Future<dynamic> delete(String path) => _req('DELETE', path);

  /// Pedido não autenticado (login/register) — usa o Dio base sem token.
  Future<dynamic> postPublic(String path, dynamic data) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] ?? e.message ?? 'Request failed',
        status: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }
}

/// ── Endpoints agrupados, espelhando lib/api.ts ──────────────────────────
class AuthApi {
  final _c = ApiClient.instance;

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _c.postPublic('/auth/login', {'username': username, 'password': password});
    return data;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final data = await _c.postPublic('/auth/register', body);
    return data;
  }

  Future<Map<String, dynamic>> me() async => await _c.get('/auth/me');
  Future<Map<String, dynamic>> update(Map<String, dynamic> body) async => await _c.put('/auth/me', body);
  Future<void> changePassword(Map<String, dynamic> body) async => await _c.post('/auth/change-password', body);
  Future<void> logout(String? refreshToken) async {
    try {
      await _c.post('/auth/logout', {'refresh_token': refreshToken});
    } catch (_) {}
  }
}

class CatalogApi {
  final _c = ApiClient.instance;
  Future<Map<String, dynamic>> list([Map<String, dynamic> params = const {}]) async =>
      await _c.get('/catalog?${Uri(queryParameters: _stringify(params)).query}');
  Future<List<dynamic>> featured([int limit = 6]) async {
    final r = await _c.get('/catalog/featured?limit=$limit');
    return (r is List) ? r : (r['items'] ?? []);
  }
  Future<List<dynamic>> latest(String type, [int limit = 12]) async {
    final r = await _c.get('/catalog/latest?type=$type&limit=$limit');
    return (r is List) ? r : (r['items'] ?? []);
  }
}

class ContentApi {
  final _c = ApiClient.instance;
  Future<Map<String, dynamic>> get(String id, [String lang = 'pt']) async =>
      await _c.get('/content/$id?lang=$lang');
  Future<Map<String, dynamic>> getStream(String id, [Map<String, dynamic> p = const {}]) async =>
      await _c.get('/content/$id/stream?${Uri(queryParameters: _stringify(p)).query}');
}

class SearchApi {
  final _c = ApiClient.instance;
  Future<Map<String, dynamic>> search(String q, [Map<String, dynamic> p = const {}]) async =>
      await _c.get('/search?${Uri(queryParameters: _stringify({'q': q, ...p})).query}');
  Future<List<dynamic>> popular() async {
    final r = await _c.get('/search/popular');
    return (r is List) ? r : [];
  }
}

class ChannelsApi {
  final _c = ApiClient.instance;
  Future<Map<String, dynamic>> list([Map<String, dynamic> p = const {}]) async =>
      await _c.get('/channels?${Uri(queryParameters: _stringify(p)).query}');
  Future<List<dynamic>> categories() async {
    final r = await _c.get('/channels/categories');
    return (r is List) ? r : (r['categories'] ?? []);
  }
  Future<Map<String, dynamic>> get(String id) async => await _c.get('/channels/$id');
  Future<Map<String, dynamic>> search(String q) async =>
      await _c.get('/channels/search?q=${Uri.encodeQueryComponent(q)}');
}

class PaymentsApi {
  final _c = ApiClient.instance;
  Future<List<dynamic>> plans() async {
    final r = await _c.get('/payments/plans');
    return (r is List) ? r : (r['plans'] ?? []);
  }
  Future<Map<String, dynamic>> convert() async => await _c.get('/payments/convert');
  Future<Map<String, dynamic>> create([Map<String, dynamic> d = const {}]) async =>
      await _c.post('/payments/create', d);
  Future<Map<String, dynamic>> status(String paymentId) async =>
      await _c.get('/payments/status/$paymentId');
}

class ProgressApi {
  final _c = ApiClient.instance;
  Future<void> update({
    required String profileId,
    required String contentId,
    String? episodeId,
    String lang = 'pt',
    required double progress,
    int? duration,
  }) async {
    await _c.post('/progress/update', {
      'profileId': profileId,
      'contentId': contentId,
      'episodeId': episodeId,
      'lang': lang,
      'progress': progress,
      'duration': duration,
    });
  }

  Future<List<dynamic>> continueWatching([Map<String, dynamic> p = const {}]) async {
    final r = await _c.get('/progress/continue?${Uri(queryParameters: _stringify(p)).query}');
    return (r is List) ? r : [];
  }
}

class MyListApi {
  final _c = ApiClient.instance;
  Future<Map<String, dynamic>> list([Map<String, dynamic> p = const {}]) async =>
      await _c.get('/mylist?${Uri(queryParameters: _stringify(p)).query}');
  Future<void> add(String profileId, String contentId) async =>
      await _c.post('/mylist/add', {'profileId': profileId, 'contentId': contentId});
  Future<void> remove(String profileId, String contentId) async =>
      await _c.post('/mylist/remove', {'profileId': profileId, 'contentId': contentId});
}

Map<String, String> _stringify(Map<String, dynamic> m) =>
    m.map((k, v) => MapEntry(k, v?.toString() ?? ''))..removeWhere((k, v) => v.isEmpty);

final authApi = AuthApi();
final catalogApi = CatalogApi();
final contentApi = ContentApi();
final searchApi = SearchApi();
final channelsApi = ChannelsApi();
final paymentsApi = PaymentsApi();
final progressApi = ProgressApi();
final myListApi = MyListApi();
