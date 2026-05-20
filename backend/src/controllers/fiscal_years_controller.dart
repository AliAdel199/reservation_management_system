import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/fiscal_years_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class FiscalYearsController {
  const FiscalYearsController({
    required DatabaseService database,
    required FiscalYearsRepository fiscalYearsRepository,
    required AuditService auditService,
  }) : _database = database,
       _fiscalYearsRepository = fiscalYearsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final FiscalYearsRepository _fiscalYearsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;
    final result = await _fiscalYearsRepository.list(
      _database.connection,
      search: search,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Fiscal years retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final created = await _database.runTx((session) async {
      final duplicate = await _fiscalYearsRepository.findByYear(
        session,
        payload.year,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Fiscal year already exists.',
          statusCode: 409,
          code: 'FISCAL_YEAR_EXISTS',
        );
      }

      final fiscalYear = await _fiscalYearsRepository.create(
        session: session,
        year: payload.year,
        name: payload.name,
        startDate: payload.startDate,
        endDate: payload.endDate,
        isActive: payload.isActive,
      );
      await _auditService.log(
        session: session,
        actor: user,
        action: 'FISCAL_YEAR_CREATED',
        entityName: 'fiscal_years',
        entityId: fiscalYear.id,
        newValues: fiscalYear.toJson(),
      );
      return fiscalYear;
    });

    return jsonResponse(
      201,
      message: 'Fiscal year created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final updated = await _database.runTx((session) async {
      final current = await _fiscalYearsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Fiscal year not found.',
          statusCode: 404,
          code: 'FISCAL_YEAR_NOT_FOUND',
        );
      }

      final duplicate = await _fiscalYearsRepository.findByYear(
        session,
        payload.year,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Fiscal year already exists.',
          statusCode: 409,
          code: 'FISCAL_YEAR_EXISTS',
        );
      }

      final fiscalYear = await _fiscalYearsRepository.update(
        session: session,
        id: id,
        year: payload.year,
        name: payload.name,
        startDate: payload.startDate,
        endDate: payload.endDate,
        isActive: payload.isActive,
      );
      await _auditService.log(
        session: session,
        actor: user,
        action: 'FISCAL_YEAR_UPDATED',
        entityName: 'fiscal_years',
        entityId: id,
        oldValues: current.toJson(),
        newValues: fiscalYear.toJson(),
      );
      return fiscalYear;
    });

    return jsonResponse(
      200,
      message: 'Fiscal year updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> activate(Request request, String id) async {
    final user = _requestUser(request);
    final activated = await _database.runTx((session) async {
      final current = await _fiscalYearsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Fiscal year not found.',
          statusCode: 404,
          code: 'FISCAL_YEAR_NOT_FOUND',
        );
      }

      final fiscalYear = await _fiscalYearsRepository.activate(session, id);
      await _auditService.log(
        session: session,
        actor: user,
        action: 'FISCAL_YEAR_ACTIVATED',
        entityName: 'fiscal_years',
        entityId: id,
        oldValues: current.toJson(),
        newValues: fiscalYear.toJson(),
      );
      return fiscalYear;
    });

    return jsonResponse(
      200,
      message: 'Fiscal year activated successfully.',
      data: activated.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final user = _requestUser(request);
    await _database.runTx((session) async {
      final current = await _fiscalYearsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Fiscal year not found.',
          statusCode: 404,
          code: 'FISCAL_YEAR_NOT_FOUND',
        );
      }

      await _fiscalYearsRepository.delete(session, id);
      await _auditService.log(
        session: session,
        actor: user,
        action: 'FISCAL_YEAR_DELETED',
        entityName: 'fiscal_years',
        entityId: id,
        oldValues: current.toJson(),
      );
    });

    return jsonResponse(200, message: 'Fiscal year deleted successfully.');
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

  _FiscalYearPayload _validateBody(Map<String, dynamic> body) {
    final year = int.tryParse(body['year']?.toString() ?? '');
    final name = body['name']?.toString().trim() ?? '';
    final startDate = body['start_date']?.toString().trim() ?? '';
    final endDate = body['end_date']?.toString().trim() ?? '';
    final isActive = body['is_active'] as bool? ?? false;

    if (year == null || name.isEmpty || startDate.isEmpty || endDate.isEmpty) {
      throw const AppException(
        message: 'Year, name, start date, and end date are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    if (year < 2000 || year > 2100) {
      throw const AppException(
        message: 'Fiscal year is out of accepted range.',
        statusCode: 422,
        code: 'INVALID_FISCAL_YEAR',
      );
    }

    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null || end.isBefore(start)) {
      throw const AppException(
        message: 'Fiscal year dates are invalid.',
        statusCode: 422,
        code: 'INVALID_FISCAL_YEAR_DATES',
      );
    }

    return _FiscalYearPayload(
      year: year,
      name: name,
      startDate: startDate,
      endDate: endDate,
      isActive: isActive,
    );
  }
}

class _FiscalYearPayload {
  const _FiscalYearPayload({
    required this.year,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  final int year;
  final String name;
  final String startDate;
  final String endDate;
  final bool isActive;
}
