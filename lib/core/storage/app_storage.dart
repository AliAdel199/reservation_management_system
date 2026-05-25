import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/auth_session.dart';

class AppStorage {
  static const _tokenKey = 'access_token';
  static const _sessionKey = 'auth_session';
  static const _apiBaseUrlKey = 'api_base_url';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveSession(AuthSession session) async {
    final prefs = await _prefs;
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<AuthSession?> readSession() async {
    final prefs = await _prefs;
    final rawSession = prefs.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    return AuthSession.fromJson(jsonDecode(rawSession) as Map<String, dynamic>);
  }

  Future<String?> readAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  Future<String?> readApiBaseUrl() async {
    final prefs = await _prefs;
    return prefs.getString(_apiBaseUrlKey);
  }

  Future<void> saveApiBaseUrl(String url) async {
    final prefs = await _prefs;
    await prefs.setString(_apiBaseUrlKey, url);
  }

  Future<void> clearApiBaseUrl() async {
    final prefs = await _prefs;
    await prefs.remove(_apiBaseUrlKey);
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_sessionKey);
  }
}
