import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/funding_item.dart';
import '../models/funding_movement_item.dart';

class FundingsRepository {
  const FundingsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<FundingItem>> fetchFundings({
    required String search,
    required String? programId,
    required String? budgetSectionId,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/fundings',
        queryParameters: {
          'search': search,
          'program_id': programId,
          'budget_section_id': budgetSectionId,
          'page': page,
          'page_size': pageSize,
        },
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة التخصيصات من الخادم.',
          code: 'INVALID_FUNDINGS_RESPONSE',
        );
      }

      return PagedResult<FundingItem>.fromJson(payload, FundingItem.fromJson);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createFunding(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/fundings', data: payload);
    } on DioException catch (exception) {
      throw _fundingException(exception);
    }
  }

  Future<void> updateFunding({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/fundings/$id', data: payload);
    } on DioException catch (exception) {
      throw _fundingException(exception);
    }
  }

  Future<void> transferAllocation(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/fundings/transfers', data: payload);
    } on DioException catch (exception) {
      throw _fundingException(exception);
    }
  }

  Future<List<FundingMovementItem>> fetchMovements({
    String? programId,
    String? budgetSectionId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/fundings/movements',
        queryParameters: {
          'program_id': programId,
          'budget_section_id': budgetSectionId,
          'from_date': fromDate,
          'to_date': toDate,
          'limit': 500,
        },
      );

      final data = response.data?['data'];
      final items = data is Map<String, dynamic> ? data['items'] : null;
      if (items is! List) {
        throw const AppException(
          message: 'تعذر قراءة تقرير حركة التخصيصات من الخادم.',
          code: 'INVALID_FUNDING_MOVEMENTS_RESPONSE',
        );
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(FundingMovementItem.fromJson)
          .toList();
    } on DioException catch (exception) {
      throw _fundingException(exception);
    }
  }

  AppException _fundingException(DioException exception) {
    final appException = AppException.fromDioException(exception);
    if (appException.code == 'FUNDING_REFERENCE_EXISTS') {
      return AppException(
        message:
            'مرجع التخصيص مستخدم مسبقاً. غيّر المرجع أو تأكد من السجل الصحيح.',
        statusCode: appException.statusCode,
        code: appException.code,
      );
    }
    if (appException.code == 'INSUFFICIENT_SOURCE_ALLOCATION') {
      return AppException(
        message: appException.message,
        statusCode: appException.statusCode,
        code: appException.code,
      );
    }
    return appException;
  }
}
