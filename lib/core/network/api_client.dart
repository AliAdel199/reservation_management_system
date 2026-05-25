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
      ),
    );
  }

  final AppStorage _storage;
  final Dio _dio;

  Dio get instance => _dio;
}
