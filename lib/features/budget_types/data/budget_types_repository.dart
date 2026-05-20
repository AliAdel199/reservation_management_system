import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/budget_type_item.dart';

class BudgetTypesRepository {
  const BudgetTypesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<BudgetTypeItem>> fetchBudgetTypes({
    required String search,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/budget-types',
        queryParameters: {
          'search': search,
          'page': page,
          'page_size': pageSize,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة أنواع الميزانيات من الخادم.',
          code: 'INVALID_BUDGET_TYPES_RESPONSE',
        );
      }
      return PagedResult<BudgetTypeItem>.fromJson(
        payload,
        BudgetTypeItem.fromJson,
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createBudgetType(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/budget-types', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateBudgetType({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/budget-types/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteBudgetType(String id) async {
    try {
      await _apiClient.instance.delete('/budget-types/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
