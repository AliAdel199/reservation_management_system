import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/institution_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class InstitutionController {
  const InstitutionController({
    required DatabaseService database,
    required InstitutionRepository institutionRepository,
    required AuditService auditService,
  }) : _database = database,
       _institutionRepository = institutionRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final InstitutionRepository _institutionRepository;
  final AuditService _auditService;

  Future<Response> get(Request request) async {
    final settings = await _institutionRepository.get(_database.connection);
    return jsonResponse(
      200,
      message: 'Institution settings retrieved successfully.',
      data: settings.toJson(),
    );
  }

  Future<Response> update(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final name = body['name']?.toString().trim() ?? '';

    if (name.isEmpty) {
      throw const AppException(
        message: 'Institution name is required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final updated = await _database.runTx((session) async {
      final current = await _institutionRepository.get(session);
      final settings = await _institutionRepository.update(
        session: session,
        id: current.id,
        name: name,
        ministryName: _optional(body['ministry_name']),
        departmentName: _optional(body['department_name']),
        sectionName: _optional(body['section_name']),
        divisionName: _optional(body['division_name']),
        address: _optional(body['address']),
        phone: _optional(body['phone']),
        email: _optional(body['email']),
        website: _optional(body['website']),
        logoPath: _optional(body['logo_path']),
        documentHeader: _optional(body['document_header']),
        documentFooter: _optional(body['document_footer']),
        reportTitle: _optional(body['report_title']),
        showReportSignatures: body['show_report_signatures'] == true,
        reportSignatures: _reportSignatures(body['report_signatures']),
        updatedBy: requestUser.id,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'INSTITUTION_UPDATED',
        entityName: 'institution_settings',
        entityId: current.id,
        description: 'Institution settings updated.',
        oldValues: current.toJson(),
        newValues: settings.toJson(),
      );

      return settings;
    });

    return jsonResponse(
      200,
      message: 'Institution settings updated successfully.',
      data: updated.toJson(),
    );
  }

  String? _optional(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  List<Map<String, dynamic>> _reportSignatures(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];

    final signatures = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) continue;
      final title = _optional(item['title']);
      final name = _optional(item['name']);
      final location = _optional(item['location']);
      if (title == null && name == null && location == null) continue;
      signatures.add({'title': title, 'name': name, 'location': location});
      if (signatures.length == 5) break;
    }

    return signatures;
  }

  RequestUser _requestUser(Request request) {
    final requestUser = request.context[requestUserContextKey] as RequestUser?;
    if (requestUser == null) {
      throw const AppException(
        message: 'Authentication context is missing.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }
    return requestUser;
  }
}
