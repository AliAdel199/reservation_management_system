import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/audit_log_item.dart';

class AuditLogsRepository {
  const AuditLogsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<AuditLogItem>> fetchAuditLogs({
    required String search,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/audit-logs',
        queryParameters: {
          'search': search,
          'page': page,
          'page_size': pageSize,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة سجل الإجراءات.',
          code: 'INVALID_AUDIT_LOGS_RESPONSE',
        );
      }
      return PagedResult.fromJson(payload, AuditLogItem.fromJson);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
