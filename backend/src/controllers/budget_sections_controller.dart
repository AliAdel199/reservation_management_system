import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/budget_sections_repository.dart';
import '../repositories/programs_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class BudgetSectionsController {
  const BudgetSectionsController({
    required DatabaseService database,
    required BudgetSectionsRepository budgetSectionsRepository,
    required ProgramsRepository programsRepository,
    required AuditService auditService,
  }) : _database = database,
       _budgetSectionsRepository = budgetSectionsRepository,
       _programsRepository = programsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final BudgetSectionsRepository _budgetSectionsRepository;
  final ProgramsRepository _programsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;
    final programId = request.url.queryParameters['program_id'];
    final fiscalYearId = request.url.queryParameters['fiscal_year_id'];
    final budgetTypeId = request.url.queryParameters['budget_type_id'];

    final result = await _budgetSectionsRepository.list(
      _database.connection,
      search: search,
      programId: programId?.isEmpty == true ? null : programId,
      fiscalYearId: fiscalYearId?.isEmpty == true ? null : fiscalYearId,
      budgetTypeId: budgetTypeId?.isEmpty == true ? null : budgetTypeId,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Budget sections retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final programId = body['program_id']?.toString().trim() ?? '';
    final fiscalYearId = body['fiscal_year_id']?.toString().trim() ?? '';
    final budgetTypeId = body['budget_type_id']?.toString().trim() ?? '';
    final parentId = body['parent_id']?.toString().trim();
    final code = body['code']?.toString().trim() ?? '';
    final name = body['name']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final allocatedAmount =
        double.tryParse(body['allocated_amount']?.toString() ?? '') ?? 0;
    final isPostable = body['is_postable'] as bool? ?? true;
    final sortOrder = int.tryParse(body['sort_order']?.toString() ?? '') ?? 0;

    _validatePayload(
      programId: programId,
      fiscalYearId: fiscalYearId,
      code: code,
      name: name,
      allocatedAmount: allocatedAmount,
      isPostable: isPostable,
    );

    final createdBudgetSection = await _database.runTx((session) async {
      final program = await _programsRepository.findById(session, programId);
      if (program == null) {
        throw const AppException(
          message: 'Parent program not found.',
          statusCode: 404,
          code: 'PROGRAM_NOT_FOUND',
        );
      }

      // تعليق عربي: تم دمج أنواع الميزانيات مع البرامج في الواجهة،
      // لذلك نشتق النوع الداخلي من البرنامج حتى تبقى العلاقات المالية صحيحة.
      final resolvedBudgetTypeId = budgetTypeId.isEmpty
          ? await _budgetSectionsRepository.ensureBudgetTypeForProgram(
              session,
              programId,
            )
          : budgetTypeId;

      final duplicate = await _budgetSectionsRepository.findByCode(
        session,
        programId: programId,
        fiscalYearId: fiscalYearId,
        code: code,
        parentId: parentId?.isEmpty == true ? null : parentId,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'رمز الباب موجود مسبقاً داخل نفس البرنامج والسنة المالية.',
          statusCode: 409,
          code: 'BUDGET_SECTION_CODE_EXISTS',
        );
      }

      final budgetSection = await _budgetSectionsRepository.create(
        session: session,
        programId: programId,
        fiscalYearId: fiscalYearId,
        budgetTypeId: resolvedBudgetTypeId,
        parentId: parentId?.isEmpty == true ? null : parentId,
        code: code,
        name: name,
        description: description?.isEmpty == true ? null : description,
        allocatedAmount: allocatedAmount,
        isPostable: isPostable,
        sortOrder: sortOrder,
        createdBy: requestUser.id,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'BUDGET_SECTION_CREATED',
        entityName: 'budget_sections',
        entityId: budgetSection.id,
        description: 'Budget section created.',
        newValues: budgetSection.toJson(),
      );

      return budgetSection;
    });

    return jsonResponse(
      201,
      message: 'Budget section created successfully.',
      data: createdBudgetSection.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final programId = body['program_id']?.toString().trim() ?? '';
    final fiscalYearId = body['fiscal_year_id']?.toString().trim() ?? '';
    final budgetTypeId = body['budget_type_id']?.toString().trim() ?? '';
    final parentId = body['parent_id']?.toString().trim();
    final code = body['code']?.toString().trim() ?? '';
    final name = body['name']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final allocatedAmount =
        double.tryParse(body['allocated_amount']?.toString() ?? '') ?? 0;
    final isPostable = body['is_postable'] as bool? ?? true;
    final sortOrder = int.tryParse(body['sort_order']?.toString() ?? '') ?? 0;
    final isActive = body['is_active'] as bool? ?? true;

    _validatePayload(
      programId: programId,
      fiscalYearId: fiscalYearId,
      code: code,
      name: name,
      allocatedAmount: allocatedAmount,
      isPostable: isPostable,
    );

    final updatedBudgetSection = await _database.runTx((session) async {
      final current = await _budgetSectionsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Budget section not found.',
          statusCode: 404,
          code: 'BUDGET_SECTION_NOT_FOUND',
        );
      }

      final program = await _programsRepository.findById(session, programId);
      if (program == null) {
        throw const AppException(
          message: 'Parent program not found.',
          statusCode: 404,
          code: 'PROGRAM_NOT_FOUND',
        );
      }

      final resolvedBudgetTypeId = budgetTypeId.isEmpty
          ? await _budgetSectionsRepository.ensureBudgetTypeForProgram(
              session,
              programId,
            )
          : budgetTypeId;

      final duplicate = await _budgetSectionsRepository.findByCode(
        session,
        programId: programId,
        fiscalYearId: fiscalYearId,
        code: code,
        parentId: parentId?.isEmpty == true ? null : parentId,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'رمز الباب موجود مسبقاً داخل نفس البرنامج والسنة المالية.',
          statusCode: 409,
          code: 'BUDGET_SECTION_CODE_EXISTS',
        );
      }

      final budgetSection = await _budgetSectionsRepository.update(
        session: session,
        id: id,
        programId: programId,
        fiscalYearId: fiscalYearId,
        budgetTypeId: resolvedBudgetTypeId,
        parentId: parentId?.isEmpty == true ? null : parentId,
        code: code,
        name: name,
        description: description?.isEmpty == true ? null : description,
        allocatedAmount: allocatedAmount,
        isPostable: isPostable,
        sortOrder: sortOrder,
        isActive: isActive,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'BUDGET_SECTION_UPDATED',
        entityName: 'budget_sections',
        entityId: id,
        description: 'Budget section updated.',
        oldValues: current.toJson(),
        newValues: budgetSection.toJson(),
      );

      return budgetSection;
    });

    return jsonResponse(
      200,
      message: 'Budget section updated successfully.',
      data: updatedBudgetSection.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final requestUser = _requestUser(request);

    final deletedBudgetSection = await _database.runTx((session) async {
      final current = await _budgetSectionsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Budget section not found.',
          statusCode: 404,
          code: 'BUDGET_SECTION_NOT_FOUND',
        );
      }

      final budgetSection = await _budgetSectionsRepository.softDelete(
        session: session,
        id: id,
        deletedBy: requestUser.id,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'BUDGET_SECTION_DELETED',
        entityName: 'budget_sections',
        entityId: id,
        description: 'Budget section soft deleted.',
        oldValues: current.toJson(),
        newValues: budgetSection.toJson(),
      );

      return budgetSection;
    });

    return jsonResponse(
      200,
      message: 'Budget section deleted successfully.',
      data: deletedBudgetSection.toJson(),
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

  void _validatePayload({
    required String programId,
    required String fiscalYearId,
    required String code,
    required String name,
    required double allocatedAmount,
    required bool isPostable,
  }) {
    if (programId.isEmpty ||
        fiscalYearId.isEmpty ||
        code.isEmpty ||
        name.isEmpty) {
      throw const AppException(
        message: 'البرنامج والسنة المالية ورمز الباب واسم الباب مطلوبة.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    if (allocatedAmount < 0) {
      throw const AppException(
        message: 'التخصيص السنوي لا يمكن أن يكون سالباً.',
        statusCode: 422,
        code: 'INVALID_ALLOCATED_AMOUNT',
      );
    }

    if (!isPostable && allocatedAmount > 0) {
      throw const AppException(
        message: 'الأبواب التجميعية لا تقبل تخصيصاً سنوياً مباشراً.',
        statusCode: 422,
        code: 'PARENT_SECTION_CANNOT_HAVE_ALLOCATION',
      );
    }
  }
}
