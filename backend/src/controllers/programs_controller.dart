import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/programs_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class ProgramsController {
  const ProgramsController({
    required DatabaseService database,
    required ProgramsRepository programsRepository,
    required AuditService auditService,
  }) : _database = database,
       _programsRepository = programsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final ProgramsRepository _programsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final fiscalYearId = request.url.queryParameters['fiscal_year_id'];
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;
    final lookup = request.url.queryParameters['lookup'] == 'true';

    if (lookup) {
      final items = await _programsRepository.lookupActive(
        _database.connection,
      );
      return jsonResponse(
        200,
        message: 'Programs lookup retrieved successfully.',
        data: {'items': items.map((item) => item.toJson()).toList()},
      );
    }

    final result = await _programsRepository.list(
      _database.connection,
      search: search,
      fiscalYearId: fiscalYearId,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Programs retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final requestedCode = body['code']?.toString().trim() ?? '';
    final name = body['name']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final fiscalYearId = body['fiscal_year_id']?.toString().trim();
    var fiscalYear = int.tryParse(body['fiscal_year']?.toString() ?? '');

    _validateProgramPayload(
      name: name,
      fiscalYear: fiscalYear,
      fiscalYearId: fiscalYearId,
    );

    final createdProgram = await _database.runTx((session) async {
      if (fiscalYearId?.isNotEmpty == true) {
        fiscalYear = await _programsRepository.findFiscalYearNumberById(
          session,
          fiscalYearId!,
        );
        if (fiscalYear == null) {
          throw const AppException(
            message: 'Fiscal year not found.',
            statusCode: 404,
            code: 'FISCAL_YEAR_NOT_FOUND',
          );
        }
      }

      // تعليق عربي: رمز البرنامج لم يعد حقلاً تشغيلياً للمستخدم، لذلك نولده داخلياً عند عدم إرساله.
      final code = requestedCode.isEmpty
          ? 'AUTO-${DateTime.now().microsecondsSinceEpoch}'
          : requestedCode;

      final existing = await _programsRepository.findByCode(session, code);
      if (existing != null) {
        throw const AppException(
          message: 'Program code already exists.',
          statusCode: 409,
          code: 'PROGRAM_CODE_EXISTS',
        );
      }

      final program = await _programsRepository.create(
        session: session,
        code: code,
        name: name,
        description: description?.isEmpty == true ? null : description,
        fiscalYearId: fiscalYearId?.isEmpty == true ? null : fiscalYearId,
        fiscalYear: fiscalYear!,
        createdBy: requestUser.id,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'PROGRAM_CREATED',
        entityName: 'programs',
        entityId: program.id,
        description: 'Program created.',
        newValues: program.toJson(),
      );

      return program;
    });

    return jsonResponse(
      201,
      message: 'Program created successfully.',
      data: createdProgram.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final requestedCode = body['code']?.toString().trim() ?? '';
    final name = body['name']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final fiscalYearId = body['fiscal_year_id']?.toString().trim();
    var fiscalYear = int.tryParse(body['fiscal_year']?.toString() ?? '');
    final isActive = body['is_active'] as bool? ?? true;

    _validateProgramPayload(
      name: name,
      fiscalYear: fiscalYear,
      fiscalYearId: fiscalYearId,
    );

    final updatedProgram = await _database.runTx((session) async {
      final current = await _programsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Program not found.',
          statusCode: 404,
          code: 'PROGRAM_NOT_FOUND',
        );
      }

      if (fiscalYearId?.isNotEmpty == true) {
        fiscalYear = await _programsRepository.findFiscalYearNumberById(
          session,
          fiscalYearId!,
        );
        if (fiscalYear == null) {
          throw const AppException(
            message: 'Fiscal year not found.',
            statusCode: 404,
            code: 'FISCAL_YEAR_NOT_FOUND',
          );
        }
      }

      final code = requestedCode.isEmpty ? current.code : requestedCode;

      final duplicate = await _programsRepository.findByCode(
        session,
        code,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Program code already exists.',
          statusCode: 409,
          code: 'PROGRAM_CODE_EXISTS',
        );
      }

      final program = await _programsRepository.update(
        session: session,
        id: id,
        code: code,
        name: name,
        description: description?.isEmpty == true ? null : description,
        fiscalYearId: fiscalYearId?.isEmpty == true ? null : fiscalYearId,
        fiscalYear: fiscalYear!,
        isActive: isActive,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'PROGRAM_UPDATED',
        entityName: 'programs',
        entityId: id,
        description: 'Program updated.',
        oldValues: current.toJson(),
        newValues: program.toJson(),
      );

      return program;
    });

    return jsonResponse(
      200,
      message: 'Program updated successfully.',
      data: updatedProgram.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final requestUser = _requestUser(request);
    final deletedProgram = await _database.runTx((session) async {
      final current = await _programsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Program not found.',
          statusCode: 404,
          code: 'PROGRAM_NOT_FOUND',
        );
      }

      final program = await _programsRepository.softDelete(
        session: session,
        id: id,
        deletedBy: requestUser.id,
      );
      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'PROGRAM_DELETED',
        entityName: 'programs',
        entityId: id,
        description: 'Program soft deleted.',
        oldValues: current.toJson(),
        newValues: program.toJson(),
      );

      return program;
    });

    return jsonResponse(
      200,
      message: 'Program deleted successfully.',
      data: deletedProgram.toJson(),
    );
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

  void _validateProgramPayload({
    required String name,
    required int? fiscalYear,
    required String? fiscalYearId,
  }) {
    if (name.isEmpty ||
        (fiscalYear == null &&
            (fiscalYearId == null || fiscalYearId.isEmpty))) {
      throw const AppException(
        message: 'Program name and fiscal year are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    if (fiscalYear != null && (fiscalYear < 2000 || fiscalYear > 2100)) {
      throw const AppException(
        message: 'Fiscal year is out of the accepted range.',
        statusCode: 422,
        code: 'INVALID_FISCAL_YEAR',
      );
    }
  }
}
