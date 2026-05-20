import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/program_item.dart';

class ProgramsRepository {
  const ProgramsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<ProgramItem>> fetchPrograms({
    required String search,
    required String? fiscalYearId,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/programs',
        queryParameters: {
          'search': search,
          if (fiscalYearId != null && fiscalYearId.isNotEmpty)
            'fiscal_year_id': fiscalYearId,
          'page': page,
          'page_size': pageSize,
        },
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة البرامج من الخادم.',
          code: 'INVALID_PROGRAMS_RESPONSE',
        );
      }

      return PagedResult<ProgramItem>.fromJson(payload, ProgramItem.fromJson);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<ProgramItem>> fetchProgramLookup() async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/programs',
        queryParameters: {'lookup': true},
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة مرجع البرامج.',
          code: 'INVALID_PROGRAMS_LOOKUP',
        );
      }

      final rawItems = payload['items'] as List<dynamic>? ?? const [];
      return rawItems
          .whereType<Map>()
          .map((item) => ProgramItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createProgram(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/programs', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateProgram({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/programs/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteProgram(String id) async {
    try {
      await _apiClient.instance.delete('/programs/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
