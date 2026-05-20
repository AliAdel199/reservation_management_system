import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../repositories/reports_repository.dart';
import '../services/api_response.dart';

class ReportsController {
  const ReportsController({
    required DatabaseService database,
    required ReportsRepository reportsRepository,
  }) : _database = database,
       _reportsRepository = reportsRepository;

  final DatabaseService _database;
  final ReportsRepository _reportsRepository;

  Future<Response> sectionSummary(Request request) async {
    final rows = await _reportsRepository.sectionSummary(
      _database.connection,
      fiscalYearId: _emptyToNull(request.url.queryParameters['fiscal_year_id']),
      budgetTypeId: _emptyToNull(request.url.queryParameters['budget_type_id']),
      programId: _emptyToNull(request.url.queryParameters['program_id']),
      sectionId: _emptyToNull(request.url.queryParameters['section_id']),
      dateFrom: _emptyToNull(request.url.queryParameters['date_from']),
      dateTo: _emptyToNull(request.url.queryParameters['date_to']),
    );

    return jsonResponse(
      200,
      message: 'Section summary report retrieved successfully.',
      data: {'items': rows, 'total': rows.length},
    );
  }

  String? _emptyToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
