import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/section_summary_item.dart';

class ReportsRepository {
  const ReportsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SectionSummaryItem>> fetchSectionSummary({
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String? programId,
    required String? sectionId,
    required String? dateFrom,
    required String? dateTo,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/reports/section-summary',
        queryParameters: {
          'fiscal_year_id': fiscalYearId,
          'budget_type_id': budgetTypeId,
          'program_id': programId,
          'section_id': sectionId,
          'date_from': dateFrom,
          'date_to': dateTo,
        },
      );

      final payload = response.data?['data'];
      final items = payload is Map<String, dynamic> ? payload['items'] : null;
      if (items is! List) {
        throw const AppException(
          message: 'تعذر قراءة تقرير ملخص الباب من الخادم.',
          code: 'INVALID_REPORT_RESPONSE',
        );
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(SectionSummaryItem.fromJson)
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
