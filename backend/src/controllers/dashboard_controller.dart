import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../repositories/dashboard_repository.dart';
import '../services/api_response.dart';

class DashboardController {
  const DashboardController({
    required DatabaseService database,
    required DashboardRepository dashboardRepository,
  }) : _database = database,
       _dashboardRepository = dashboardRepository;

  final DatabaseService _database;
  final DashboardRepository _dashboardRepository;

  Future<Response> summary(Request request) async {
    final fiscalYearId = request.url.queryParameters['fiscal_year_id'];
    final summary = await _dashboardRepository.fetchSummary(
      _database.connection,
      fiscalYearId: fiscalYearId == null || fiscalYearId.trim().isEmpty
          ? null
          : fiscalYearId.trim(),
    );
    return jsonResponse(
      200,
      message: 'Dashboard summary retrieved successfully.',
      data: summary.toJson(),
    );
  }

  Future<Response> alerts(Request request) async {
    final fiscalYearId = request.url.queryParameters['fiscal_year_id'];
    final thresholdText = request.url.queryParameters['threshold'];
    final threshold = double.tryParse(thresholdText ?? '') ?? 50000;

    final alerts = await _dashboardRepository.fetchBalanceAlerts(
      _database.connection,
      fiscalYearId: fiscalYearId == null || fiscalYearId.trim().isEmpty
          ? null
          : fiscalYearId.trim(),
      threshold: threshold,
      limit: 100,
    );

    return jsonResponse(
      200,
      message: 'Balance alerts retrieved successfully.',
      data: {'items': alerts.map((alert) => alert.toJson()).toList()},
    );
  }
}
