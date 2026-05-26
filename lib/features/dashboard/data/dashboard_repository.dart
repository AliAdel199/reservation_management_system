import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/dashboard_summary.dart';

class DashboardRepository {
  const DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> fetchSummary({String? fiscalYearId}) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/dashboard/summary',
        queryParameters: {
          if (fiscalYearId != null && fiscalYearId.isNotEmpty)
            'fiscal_year_id': fiscalYearId,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message:
              'تعذر قراءة بيانات لوحة التحكم. تأكد من أن التطبيق متصل بالـ API الصحيح على المنفذ 7070.',
          code: 'INVALID_DASHBOARD_RESPONSE',
        );
      }
      return DashboardSummary.fromJson(payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<DashboardBalanceAlert>> fetchBalanceAlerts({
    String? fiscalYearId,
    double threshold = 50000,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/dashboard/alerts',
        queryParameters: {
          if (fiscalYearId != null && fiscalYearId.isNotEmpty)
            'fiscal_year_id': fiscalYearId,
          'threshold': threshold,
        },
      );
      final payload = response.data?['data']?['items'];
      if (payload is! List) {
        throw const AppException(
          message: 'تعذر قراءة تنبيهات الرصيد من الخادم.',
          code: 'INVALID_BALANCE_ALERTS_RESPONSE',
        );
      }

      return payload
          .whereType<Map>()
          .map(
            (item) =>
                DashboardBalanceAlert.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<DashboardSectionCard>> fetchSectionCards({
    String? fiscalYearId,
    int level = 3,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/dashboard/section-cards',
        queryParameters: {
          if (fiscalYearId != null && fiscalYearId.isNotEmpty)
            'fiscal_year_id': fiscalYearId,
          'level': level,
          'limit': limit,
        },
      );
      final payload = response.data?['data']?['items'];
      if (payload is! List) {
        throw const AppException(
          message: 'تعذر قراءة كاردات أبواب الداشبورد من الخادم.',
          code: 'INVALID_DASHBOARD_SECTION_CARDS_RESPONSE',
        );
      }

      return payload
          .whereType<Map>()
          .map(
            (item) =>
                DashboardSectionCard.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<DashboardAnalytics> fetchAnalytics({
    String? fiscalYearId,
    int limit = 8,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/dashboard/analytics',
        queryParameters: {
          if (fiscalYearId != null && fiscalYearId.isNotEmpty)
            'fiscal_year_id': fiscalYearId,
          'limit': limit,
        },
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة بيانات التحليلات من الخادم.',
          code: 'INVALID_DASHBOARD_ANALYTICS_RESPONSE',
        );
      }

      return DashboardAnalytics.fromJson(payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
