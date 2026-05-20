import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../repositories/audit_logs_repository.dart';
import '../services/api_response.dart';

class AuditLogsController {
  const AuditLogsController({
    required DatabaseService database,
    required AuditLogsRepository auditLogsRepository,
  }) : _database = database,
       _auditLogsRepository = auditLogsRepository;

  final DatabaseService _database;
  final AuditLogsRepository _auditLogsRepository;

  Future<Response> list(Request request) async {
    final query = request.url.queryParameters;
    final result = await _auditLogsRepository.list(
      _database.connection,
      search: query['search'] ?? '',
      action: query['action'] ?? '',
      entityType: query['entity_type'] ?? '',
      userId: query['user_id'],
      dateFrom: query['date_from'],
      dateTo: query['date_to'],
      page: int.tryParse(query['page'] ?? '1') ?? 1,
      pageSize: int.tryParse(query['page_size'] ?? '20') ?? 20,
    );

    return jsonResponse(
      200,
      message: 'Audit logs retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }
}
