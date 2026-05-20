import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/managed_user_item.dart';

class UsersRepository {
  const UsersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<ManagedUserItem>> fetchUsers({
    required String search,
    required String? roleId,
    required bool? isActive,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/users',
        queryParameters: {
          'search': search,
          if (roleId != null && roleId.isNotEmpty) 'role_id': roleId,
          if (isActive != null) 'is_active': isActive,
          'page': page,
          'page_size': pageSize,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة المستخدمين.',
          code: 'INVALID_USERS_RESPONSE',
        );
      }
      return PagedResult.fromJson(payload, ManagedUserItem.fromJson);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<UserRoleItem>> fetchRoles() async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/users/roles',
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة الأدوار.',
          code: 'INVALID_ROLES_RESPONSE',
        );
      }
      final items = payload['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map>()
          .map((item) => UserRoleItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/users', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.put('/users/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> setStatus(String id, bool isActive) async {
    try {
      await _apiClient.instance.patch(
        '/users/$id/status',
        data: {'is_active': isActive},
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updatePassword(String id, String password) async {
    try {
      await _apiClient.instance.patch(
        '/users/$id/password',
        data: {'password': password},
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
