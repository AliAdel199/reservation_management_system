import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/monthly_funding_item.dart';

class MonthlyFundingsRepository {
  const MonthlyFundingsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<MonthlyFundingItem>> fetchMonthlyFundings({
    required String search,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String? programId,
    required String? sectionId,
    required int? month,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/monthly-fundings',
        queryParameters: {
          'search': search,
          'fiscal_year_id': fiscalYearId,
          'budget_type_id': budgetTypeId,
          'program_id': programId,
          'section_id': sectionId,
          'month': month,
          'page': page,
          'page_size': pageSize,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة التمويلات الشهرية من الخادم.',
          code: 'INVALID_MONTHLY_FUNDINGS_RESPONSE',
        );
      }
      return PagedResult<MonthlyFundingItem>.fromJson(
        payload,
        MonthlyFundingItem.fromJson,
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createMonthlyFunding(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/monthly-fundings', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateMonthlyFunding({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/monthly-fundings/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteMonthlyFunding(String id) async {
    try {
      await _apiClient.instance.delete('/monthly-fundings/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
