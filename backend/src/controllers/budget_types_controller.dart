import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/budget_types_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class BudgetTypesController {
  const BudgetTypesController({
    required DatabaseService database,
    required BudgetTypesRepository budgetTypesRepository,
    required AuditService auditService,
  }) : _database = database,
       _budgetTypesRepository = budgetTypesRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final BudgetTypesRepository _budgetTypesRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;
    final result = await _budgetTypesRepository.list(
      _database.connection,
      search: search,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );
    return jsonResponse(
      200,
      message: 'Budget types retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final created = await _database.runTx((session) async {
      final duplicate = await _budgetTypesRepository.findByCode(
        session,
        payload.code,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Budget type code already exists.',
          statusCode: 409,
          code: 'BUDGET_TYPE_CODE_EXISTS',
        );
      }
      final budgetType = await _budgetTypesRepository.create(
        session: session,
        code: payload.code,
        name: payload.name,
        description: payload.description,
        isActive: payload.isActive,
      );
      await _auditService.log(
        session: session,
        actor: user,
        action: 'BUDGET_TYPE_CREATED',
        entityName: 'budget_types',
        entityId: budgetType.id,
        newValues: budgetType.toJson(),
      );
      return budgetType;
    });

    return jsonResponse(
      201,
      message: 'Budget type created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final updated = await _database.runTx((session) async {
      final current = await _budgetTypesRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Budget type not found.',
          statusCode: 404,
          code: 'BUDGET_TYPE_NOT_FOUND',
        );
      }

      final duplicate = await _budgetTypesRepository.findByCode(
        session,
        payload.code,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Budget type code already exists.',
          statusCode: 409,
          code: 'BUDGET_TYPE_CODE_EXISTS',
        );
      }

      final budgetType = await _budgetTypesRepository.update(
        session: session,
        id: id,
        code: payload.code,
        name: payload.name,
        description: payload.description,
        isActive: payload.isActive,
      );
      await _auditService.log(
        session: session,
        actor: user,
        action: 'BUDGET_TYPE_UPDATED',
        entityName: 'budget_types',
        entityId: id,
        oldValues: current.toJson(),
        newValues: budgetType.toJson(),
      );
      return budgetType;
    });

    return jsonResponse(
      200,
      message: 'Budget type updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final user = _requestUser(request);
    await _database.runTx((session) async {
      final current = await _budgetTypesRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Budget type not found.',
          statusCode: 404,
          code: 'BUDGET_TYPE_NOT_FOUND',
        );
      }
      await _budgetTypesRepository.delete(session, id);
      await _auditService.log(
        session: session,
        actor: user,
        action: 'BUDGET_TYPE_DELETED',
        entityName: 'budget_types',
        entityId: id,
        oldValues: current.toJson(),
      );
    });

    return jsonResponse(200, message: 'Budget type deleted successfully.');
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

  _BudgetTypePayload _validateBody(Map<String, dynamic> body) {
    final code = body['code']?.toString().trim() ?? '';
    final name = body['name']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final isActive = body['is_active'] as bool? ?? true;

    if (code.isEmpty || name.isEmpty) {
      throw const AppException(
        message: 'Code and name are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }
    return _BudgetTypePayload(
      code: code.toUpperCase(),
      name: name,
      description: description?.isEmpty == true ? null : description,
      isActive: isActive,
    );
  }
}

class _BudgetTypePayload {
  const _BudgetTypePayload({
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
  });

  final String code;
  final String name;
  final String? description;
  final bool isActive;
}
