import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../../../shared/models/auth_session.dart';

class AuthRepository {
  const AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final AppStorage _storage;

  Map<String, dynamic> _extractData(Map<String, dynamic>? responseData) {
    final payload = responseData?['data'];
    if (payload is! Map<String, dynamic>) {
      throw const AppException(
        message:
            'استجابة الخادم غير متوقعة. تأكد من عنوان الـ API والمنفذ الصحيح.',
        code: 'INVALID_API_RESPONSE',
      );
    }

    return payload;
  }

  Future<AuthSession?> restoreSession() async {
    final localSession = await _storage.readSession();
    if (localSession == null) {
      return null;
    }

    try {
      // تعليق عربي: نتحقق من الجلسة من الخادم لتجنب الاعتماد على token منتهي محلياً.
      final refreshedSession = await me();
      await _storage.saveSession(refreshedSession);
      return refreshedSession;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<AuthSession> login({
    required String identity,
    required String password,
  }) async {
    try {
      final response = await _apiClient.instance.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'identity': identity, 'password': password},
      );

      final payload = _extractData(response.data);
      final session = AuthSession.fromJson(payload);
      await _storage.saveSession(session);
      return session;
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<AuthSession> me() async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/auth/me',
      );
      final payload = _extractData(response.data);
      final user = payload['user'];
      if (user is! Map<String, dynamic>) {
        throw const AppException(
          message: 'بيانات المستخدم الحالية غير مكتملة في استجابة الخادم.',
          code: 'INVALID_USER_RESPONSE',
        );
      }
      final token = await _storage.readAccessToken();

      if (token == null) {
        throw const AppException(message: 'الجلسة الحالية غير متاحة');
      }

      return AuthSession.fromJson({'token': token, 'user': user});
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> clearSession() => _storage.clearSession();
}
