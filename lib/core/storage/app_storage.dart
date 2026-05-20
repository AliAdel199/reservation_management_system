import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/auth_session.dart';

class AppStorage {
  static const _tokenKey = 'access_token';
  static const _sessionKey = 'auth_session';

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

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_sessionKey);
  }
}
