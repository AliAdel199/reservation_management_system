import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/app_storage.dart';

class ApiClient {
  ApiClient(this._storage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final configuredBaseUrl = await _storage.readApiBaseUrl();
          if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
            options.baseUrl = configuredBaseUrl;
          }

          final token = await _storage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) {
          // تعليق عربي: 401 على أي طلب غير تسجيل الدخول يعني أن الجلسة انتهت أو الحساب عُطّل.
          final isLoginRequest = error.requestOptions.path.endsWith(
            '/auth/login',
          );
          if (error.response?.statusCode == 401 && !isLoginRequest) {
            final data = error.response?.data;
            onUnauthorized?.call(
              data is Map ? data['code']?.toString() : null,
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  final AppStorage _storage;
  final Dio _dio;

  /// يُستدعى برمز الخطأ من الخادم (مثل ACCOUNT_DISABLED أو TOKEN_EXPIRED).
  void Function(String? code)? onUnauthorized;

  Dio get instance => _dio;
}
