import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/fiscal_year_item.dart';

class FiscalYearsRepository {
  const FiscalYearsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<FiscalYearItem>> fetchFiscalYears({
    required String search,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/fiscal-years',
        queryParameters: {
          'search': search,
          'page': page,
          'page_size': pageSize,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة السنوات المالية من الخادم.',
          code: 'INVALID_FISCAL_YEARS_RESPONSE',
        );
      }
      return PagedResult<FiscalYearItem>.fromJson(
        payload,
        FiscalYearItem.fromJson,
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createFiscalYear(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/fiscal-years', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateFiscalYear({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/fiscal-years/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> activateFiscalYear(String id) async {
    try {
      await _apiClient.instance.patch('/fiscal-years/$id/activate');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteFiscalYear(String id) async {
    try {
      await _apiClient.instance.delete('/fiscal-years/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
