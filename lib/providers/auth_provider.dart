import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class AuthState {
  final AppUser? user;
  final AppPlan? plan;
  final List<Profile> profiles;
  final bool hydrated;
  final bool loading;

  const AuthState({
    this.user,
    this.plan,
    this.profiles = const [],
    this.hydrated = false,
    this.loading = false,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AppUser? user,
    AppPlan? plan,
    List<Profile>? profiles,
    bool? hydrated,
    bool? loading,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      plan: clearUser ? null : (plan ?? this.plan),
      profiles: clearUser ? const [] : (profiles ?? this.profiles),
      hydrated: hydrated ?? this.hydrated,
      loading: loading ?? this.loading,
    );
  }
}

/// Equivalente a useAuthStore (Zustand) — login, logout, fetchMe.
class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState()) {
    fetchMe();
  }

  final _api = ApiClient.instance;

  Future<void> login(String username, String password) async {
    state = state.copyWith(loading: true);
    try {
      final data = await authApi.login(username, password);
      await _api.setTokens(token: data['token'], refresh: data['refresh_token']);
      state = state.copyWith(
        user: AppUser.fromJson(data['user']),
        plan: data['plan'] != null ? AppPlan.fromJson(data['plan']) : AppPlan.free(),
        profiles: ((data['profiles'] as List?) ?? []).map((p) => Profile.fromJson(p)).toList(),
        loading: false,
        hydrated: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    state = state.copyWith(loading: true);
    try {
      final data = await authApi.register(body);
      await _api.setTokens(token: data['token'], refresh: data['refresh_token']);
      state = state.copyWith(
        user: AppUser.fromJson(data['user']),
        plan: data['plan'] != null ? AppPlan.fromJson(data['plan']) : AppPlan.free(),
        profiles: ((data['profiles'] as List?) ?? []).map((p) => Profile.fromJson(p)).toList(),
        loading: false,
        hydrated: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    final rt = await _api.refreshToken;
    await authApi.logout(rt);
    await _api.clearTokens();
    state = state.copyWith(clearUser: true, loading: false, hydrated: true);
  }

  Future<void> fetchMe() async {
    final hasToken = await _api.token != null;
    final hasRefresh = await _api.refreshToken != null;
    if (!hasToken && !hasRefresh) {
      state = state.copyWith(hydrated: true);
      return;
    }
    try {
      final data = await authApi.me();
      state = state.copyWith(
        user: data['user'] != null ? AppUser.fromJson(data['user']) : null,
        plan: data['plan'] != null ? AppPlan.fromJson(data['plan']) : AppPlan.free(),
        profiles: ((data['profiles'] as List?) ?? []).map((p) => Profile.fromJson(p)).toList(),
        hydrated: true,
      );
    } catch (_) {
      await _api.clearTokens();
      state = state.copyWith(clearUser: true, hydrated: true);
    }
  }

  Future<void> refreshMe() => fetchMe();
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
