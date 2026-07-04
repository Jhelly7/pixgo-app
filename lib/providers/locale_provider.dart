import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'pixgo_lang';

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (saved != null) state = Locale(saved);
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, code);
    state = Locale(code);
  }

  Future<bool> hasChosenLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kLangKey);
  }
}

/// null enquanto o idioma ainda não foi escolhido pelo utilizador
/// (equivalente ao LanguageModal bloqueante do site).
final localeProvider = StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});
