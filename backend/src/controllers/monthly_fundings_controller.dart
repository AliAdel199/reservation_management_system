import 'package:shelf/shelf.dart';
import 'package:postgres/postgres.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/monthly_fundings_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class MonthlyFundingsController {
  const MonthlyFundingsController({
    required DatabaseService database,
    required MonthlyFundingsRepository monthlyFundingsRepository,
    required AuditService auditService,
  }) : _database = database,
       _monthlyFundingsRepository = monthlyFundingsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final MonthlyFundingsRepository _monthlyFundingsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final fiscalYearId = request.url.queryParameters['fiscal_year_id'];
    final budgetTypeId = request.url.queryParameters['budget_type_id'];
    final programId = request.url.queryParameters['program_id'];
    final sectionId = request.url.queryParameters['section_id'];
    final month = int.tryParse(request.url.queryParameters['month'] ?? '');
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;

    final result = await _monthlyFundingsRepository.list(
      _database.connection,
      search: search,
      fiscalYearId: fiscalYearId?.isEmpty == true ? null : fiscalYearId,
      budgetTypeId: budgetTypeId?.isEmpty == true ? null : budgetTypeId,
      programId: programId?.isEmpty == true ? null : programId,
      sectionId: sectionId?.isEmpty == true ? null : sectionId,
      month: month,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Monthly fundings retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final created = await _handleDuplicateFunding(() {
      return _database.runTx((session) async {
        // تعليق عربي: الواجهة تختار البرنامج فقط، ونستخرج نوع الميزانية من أبواب البرنامج لتجنب تكرار الاختيار.
        final budgetTypeId = payload.budgetTypeId?.isNotEmpty == true
            ? payload.budgetTypeId!
            : await _monthlyFundingsRepository.resolveBudgetTypeIdForProgram(
                session,
                payload.programId,
              );

        final monthlyFunding = await _monthlyFundingsRepository.create(
          session: session,
          fiscalYearId: payload.fiscalYearId,
          budgetTypeId: budgetTypeId,
          programId: payload.programId,
          sectionId: payload.sectionId,
          month: payload.month,
          amount: payload.amount,
          fundingDate: payload.fundingDate,
          notes: payload.notes,
          createdBy: user.id,
        );

        await _monthlyFundingsRepository.createLedgerTransaction(
          session: session,
          monthlyFunding: monthlyFunding,
          createdBy: user.id,
          transactionType: 'funding',
          direction: 'IN',
          amount: monthlyFunding.amount,
          description: 'Monthly funding for month ${monthlyFunding.month}.',
        );

        await _auditService.log(
          session: session,
          actor: user,
          action: 'MONTHLY_FUNDING_CREATED',
          entityName: 'monthly_fundings',
          entityId: monthlyFunding.id,
          newValues: monthlyFunding.toJson(),
        );

        return monthlyFunding;
      });
    });

    return jsonResponse(
      201,
      message: 'Monthly funding created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final updated = await _handleDuplicateFunding(() {
      return _database.runTx((session) async {
        final current = await _monthlyFundingsRepository.findById(session, id);
        if (current == null) {
          throw const AppException(
            message: 'Monthly funding not found.',
            statusCode: 404,
            code: 'MONTHLY_FUNDING_NOT_FOUND',
          );
        }

        final budgetTypeId = payload.budgetTypeId?.isNotEmpty == true
            ? payload.budgetTypeId!
            : await _monthlyFundingsRepository.resolveBudgetTypeIdForProgram(
                session,
                payload.programId,
              );

        final monthlyFunding = await _monthlyFundingsRepository.update(
          session: session,
          id: id,
          fiscalYearId: payload.fiscalYearId,
          budgetTypeId: budgetTypeId,
          programId: payload.programId,
          sectionId: payload.sectionId,
          month: payload.month,
          amount: payload.amount,
          fundingDate: payload.fundingDate,
          notes: payload.notes,
        );

        final difference = monthlyFunding.amount - current.amount;
        if (difference != 0) {
          await _monthlyFundingsRepository.createLedgerTransaction(
            session: session,
            monthlyFunding: monthlyFunding,
            createdBy: user.id,
            transactionType: 'adjustment',
            direction: difference > 0 ? 'IN' : 'OUT',
            amount: difference.abs(),
            description: 'Monthly funding adjustment.',
          );
        }

        await _auditService.log(
          session: session,
          actor: user,
          action: 'MONTHLY_FUNDING_UPDATED',
          entityName: 'monthly_fundings',
          entityId: monthlyFunding.id,
          oldValues: current.toJson(),
          newValues: monthlyFunding.toJson(),
        );

        return monthlyFunding;
      });
    });

    return jsonResponse(
      200,
      message: 'Monthly funding updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final user = _requestUser(request);
    await _database.runTx((session) async {
      final current = await _monthlyFundingsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Monthly funding not found.',
          statusCode: 404,
          code: 'MONTHLY_FUNDING_NOT_FOUND',
        );
      }

      await _monthlyFundingsRepository.softDelete(
        session: session,
        id: id,
        deletedBy: user.id,
      );
      await _monthlyFundingsRepository.createLedgerTransaction(
        session: session,
        monthlyFunding: current,
        createdBy: user.id,
        transactionType: 'adjustment',
        direction: 'OUT',
        amount: current.amount,
        description: 'Monthly funding soft delete reversal.',
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'MONTHLY_FUNDING_DELETED',
        entityName: 'monthly_fundings',
        entityId: id,
        oldValues: current.toJson(),
      );
    });

    return jsonResponse(200, message: 'Monthly funding deleted successfully.');
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

  Future<T> _handleDuplicateFunding<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on UniqueViolationException catch (exception) {
      const duplicateIndexes = {
        'uq_monthly_fundings_scope',
        'uq_monthly_fundings_active_scope',
        'uq_monthly_fundings_program_scope',
        'uq_monthly_fundings_section_scope',
      };
      if (duplicateIndexes.contains(exception.constraintName)) {
        throw const AppException(
          message:
              'هذا التمويل الشهري مسجل مسبقاً لنفس السنة والنوع والبرنامج والشهر وتاريخ التمويل. افتح السجل الموجود وعدّل المبلغ بدلاً من إضافة سجل جديد.',
          statusCode: 409,
          code: 'MONTHLY_FUNDING_ALREADY_EXISTS',
        );
      }
      rethrow;
    }
  }

  _MonthlyFundingPayload _validateBody(Map<String, dynamic> body) {
    final fiscalYearId = body['fiscal_year_id']?.toString().trim() ?? '';
    final budgetTypeId = body['budget_type_id']?.toString().trim();
    final programId = body['program_id']?.toString().trim() ?? '';
    // تعليق عربي: التمويل الشهري أصبح على مستوى البرنامج، والباب اختياري فقط للبيانات القديمة.
    final sectionId = (body['section_id'] ?? body['budget_section_id'])
        ?.toString()
        .trim();
    final month = int.tryParse(body['month']?.toString() ?? '');
    final amount = double.tryParse(body['amount']?.toString() ?? '');
    final fundingDate = body['funding_date']?.toString().trim() ?? '';
    final notes = body['notes']?.toString().trim();

    if (fiscalYearId.isEmpty ||
        programId.isEmpty ||
        month == null ||
        amount == null ||
        fundingDate.isEmpty) {
      throw const AppException(
        message:
            'Fiscal year, program, month, amount, and funding date are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    if (month < 1 || month > 12 || amount <= 0) {
      throw const AppException(
        message: 'Month or amount is invalid.',
        statusCode: 422,
        code: 'INVALID_MONTHLY_FUNDING',
      );
    }

    if (DateTime.tryParse(fundingDate) == null) {
      throw const AppException(
        message: 'Funding date is invalid.',
        statusCode: 422,
        code: 'INVALID_FUNDING_DATE',
      );
    }

    return _MonthlyFundingPayload(
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId?.isEmpty == true ? null : budgetTypeId,
      programId: programId,
      sectionId: sectionId?.isEmpty == true ? null : sectionId,
      month: month,
      amount: amount,
      fundingDate: fundingDate,
      notes: notes?.isEmpty == true ? null : notes,
    );
  }
}

class _MonthlyFundingPayload {
  const _MonthlyFundingPayload({
    required this.fiscalYearId,
    required this.budgetTypeId,
    required this.programId,
    required this.sectionId,
    required this.month,
    required this.amount,
    required this.fundingDate,
    required this.notes,
  });

  final String fiscalYearId;
  final String? budgetTypeId;
  final String programId;
  final String? sectionId;
  final int month;
  final double amount;
  final String fundingDate;
  final String? notes;
}
