import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/budget_section_item.dart';

class BudgetSectionsRepository {
  const BudgetSectionsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<BudgetSectionItem>> fetchBudgetSections({
    required String search,
    required String? programId,
    String? fiscalYearId,
    String? budgetTypeId,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/budget-sections',
        queryParameters: {
          'search': search,
          'program_id': programId,
          'fiscal_year_id': fiscalYearId,
          'budget_type_id': budgetTypeId,
          'page': page,
          'page_size': pageSize,
        },
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة الأبواب من الخادم.',
          code: 'INVALID_BUDGET_SECTIONS_RESPONSE',
        );
      }

      return PagedResult<BudgetSectionItem>.fromJson(
        payload,
        BudgetSectionItem.fromJson,
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createBudgetSection(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/budget-sections', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateBudgetSection({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/budget-sections/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteBudgetSection(String id) async {
    try {
      await _apiClient.instance.delete('/budget-sections/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
