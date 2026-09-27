import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/budget_sections_repository.dart';
import '../repositories/fundings_repository.dart';
import '../repositories/programs_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class FundingsController {
  const FundingsController({
    required DatabaseService database,
    required FundingsRepository fundingsRepository,
    required ProgramsRepository programsRepository,
    required BudgetSectionsRepository budgetSectionsRepository,
    required AuditService auditService,
  }) : _database = database,
       _fundingsRepository = fundingsRepository,
       _programsRepository = programsRepository,
       _budgetSectionsRepository = budgetSectionsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final FundingsRepository _fundingsRepository;
  final ProgramsRepository _programsRepository;
  final BudgetSectionsRepository _budgetSectionsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;
    final programId = request.url.queryParameters['program_id'];
    final budgetSectionId = request.url.queryParameters['budget_section_id'];

    final result = await _fundingsRepository.list(
      _database.connection,
      search: search,
      programId: programId?.isEmpty == true ? null : programId,
      budgetSectionId: budgetSectionId?.isEmpty == true
          ? null
          : budgetSectionId,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Fundings retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final created = await _database.runTx((session) async {
      await _ensureReferences(
        session,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
      );

      final duplicate = await _fundingsRepository.findByReference(
        session,
        payload.fundingReference,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Funding reference already exists.',
          statusCode: 409,
          code: 'FUNDING_REFERENCE_EXISTS',
        );
      }

      await _fundingsRepository.applyFundingAllocationChange(
        session: session,
        oldBudgetSectionId: null,
        oldAmount: 0,
        newBudgetSectionId: payload.budgetSectionId,
        newAmount: payload.allocatedAmount,
      );

      final funding = await _fundingsRepository.create(
        session: session,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingReference: payload.fundingReference,
        fiscalYear: payload.fiscalYear,
        allocatedAmount: payload.allocatedAmount,
        notes: payload.notes,
        createdBy: user.id,
      );

      await _fundingsRepository.createLedgerTransaction(
        session: session,
        fundingId: funding.id,
        programId: funding.programId,
        budgetSectionId: funding.budgetSectionId,
        createdBy: user.id,
        amount: funding.allocatedAmount,
        transactionType: 'allocation',
        description:
            'Initial allocation for funding ${funding.fundingReference}.',
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'FUNDING_CREATED',
        entityName: 'fundings',
        entityId: funding.id,
        description: 'Funding allocation created.',
        newValues: funding.toJson(),
      );

      return funding;
    });

    return jsonResponse(
      201,
      message: 'Funding created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final updated = await _database.runTx((session) async {
      final current = await _fundingsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Funding not found.',
          statusCode: 404,
          code: 'FUNDING_NOT_FOUND',
        );
      }

      await _ensureReferences(
        session,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
      );

      final duplicate = await _fundingsRepository.findByReference(
        session,
        payload.fundingReference,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Funding reference already exists.',
          statusCode: 409,
          code: 'FUNDING_REFERENCE_EXISTS',
        );
      }

      await _fundingsRepository.applyFundingAllocationChange(
        session: session,
        oldBudgetSectionId: current.budgetSectionId,
        oldAmount: current.allocatedAmount,
        newBudgetSectionId: payload.budgetSectionId,
        newAmount: payload.allocatedAmount,
      );

      final funding = await _fundingsRepository.update(
        session: session,
        id: id,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingReference: payload.fundingReference,
        fiscalYear: payload.fiscalYear,
        allocatedAmount: payload.allocatedAmount,
        notes: payload.notes,
      );

      final movedToDifferentSection =
          current.budgetSectionId != funding.budgetSectionId;
      if (movedToDifferentSection) {
        await _fundingsRepository.createLedgerTransaction(
          session: session,
          fundingId: current.id,
          programId: current.programId,
          budgetSectionId: current.budgetSectionId,
          createdBy: user.id,
          amount: current.allocatedAmount,
          transactionType: 'adjustment_decrease',
          description:
              'Allocation moved out from funding ${current.fundingReference}.',
        );
        await _fundingsRepository.createLedgerTransaction(
          session: session,
          fundingId: funding.id,
          programId: funding.programId,
          budgetSectionId: funding.budgetSectionId,
          createdBy: user.id,
          amount: funding.allocatedAmount,
          transactionType: 'adjustment_increase',
          description:
              'Allocation moved in for funding ${funding.fundingReference}.',
        );
      } else {
        final difference = funding.allocatedAmount - current.allocatedAmount;
        if (difference > 0) {
          await _fundingsRepository.createLedgerTransaction(
            session: session,
            fundingId: funding.id,
            programId: funding.programId,
            budgetSectionId: funding.budgetSectionId,
            createdBy: user.id,
            amount: difference,
            transactionType: 'adjustment_increase',
            description:
                'Allocation increase for funding ${funding.fundingReference}.',
          );
        } else if (difference < 0) {
          await _fundingsRepository.createLedgerTransaction(
            session: session,
            fundingId: funding.id,
            programId: funding.programId,
            budgetSectionId: funding.budgetSectionId,
            createdBy: user.id,
            amount: difference.abs(),
            transactionType: 'adjustment_decrease',
            description:
                'Allocation decrease for funding ${funding.fundingReference}.',
          );
        }
      }

      await _auditService.log(
        session: session,
        actor: user,
        action: 'FUNDING_UPDATED',
        entityName: 'fundings',
        entityId: funding.id,
        description: 'Funding allocation updated.',
        oldValues: current.toJson(),
        newValues: funding.toJson(),
      );

      return funding;
    });

    return jsonResponse(
      200,
      message: 'Funding updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> transfer(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final fromSectionId =
        body['from_budget_section_id']?.toString().trim() ?? '';
    final toSectionId = body['to_budget_section_id']?.toString().trim() ?? '';
    final amount = double.tryParse(body['amount']?.toString() ?? '');
    final reference = body['reference']?.toString().trim() ?? '';
    final notes = body['notes']?.toString().trim();

    if (fromSectionId.isEmpty ||
        toSectionId.isEmpty ||
        amount == null ||
        reference.isEmpty) {
      throw const AppException(
        message: 'باب المصدر وباب الهدف والمبلغ ورقم/مرجع المناقلة مطلوبة.',
        statusCode: 422,
        code: 'TRANSFER_VALIDATION_ERROR',
      );
    }

    await _database.runTx((session) async {
      await _fundingsRepository.transferAllocation(
        session: session,
        fromSectionId: fromSectionId,
        toSectionId: toSectionId,
        amount: amount,
        reference: reference,
        notes: notes?.isEmpty == true ? null : notes,
        createdBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'ALLOCATION_TRANSFER_CREATED',
        entityName: 'financial_transactions',
        description: 'Allocation transferred between budget sections.',
        newValues: {
          'from_budget_section_id': fromSectionId,
          'to_budget_section_id': toSectionId,
          'amount': amount,
          'reference': reference,
          'notes': notes,
        },
      );
    });

    return jsonResponse(
      201,
      message: 'Allocation transfer completed successfully.',
    );
  }

  Future<Response> movements(Request request) async {
    final programId = request.url.queryParameters['program_id'];
    final budgetSectionId = request.url.queryParameters['budget_section_id'];
    final fromDate = request.url.queryParameters['from_date'];
    final toDate = request.url.queryParameters['to_date'];
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '200') ?? 200;

    final items = await _fundingsRepository.allocationMovements(
      _database.connection,
      programId: programId?.isEmpty == true ? null : programId,
      budgetSectionId: budgetSectionId?.isEmpty == true
          ? null
          : budgetSectionId,
      fromDate: fromDate?.isEmpty == true ? null : fromDate,
      toDate: toDate?.isEmpty == true ? null : toDate,
      limit: limit.clamp(20, 1000).toInt(),
    );

    return jsonResponse(
      200,
      message: 'Allocation movements retrieved successfully.',
      data: {'items': items},
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

  Future<void> _ensureReferences(
    dynamic session, {
    required String programId,
    required String budgetSectionId,
  }) async {
    final program = await _programsRepository.findById(session, programId);
    if (program == null) {
      throw const AppException(
        message: 'Program not found.',
        statusCode: 404,
        code: 'PROGRAM_NOT_FOUND',
      );
    }

    final budgetSection = await _budgetSectionsRepository.findById(
      session,
      budgetSectionId,
    );
    if (budgetSection == null) {
      throw const AppException(
        message: 'Budget section not found.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    if (budgetSection.programId != programId) {
      throw const AppException(
        message: 'Budget section does not belong to the selected program.',
        statusCode: 422,
        code: 'PROGRAM_BUDGET_SECTION_MISMATCH',
      );
    }
  }

  _FundingPayload _validateBody(Map<String, dynamic> body) {
    final programId = body['program_id']?.toString().trim() ?? '';
    final budgetSectionId = body['budget_section_id']?.toString().trim() ?? '';
    final fundingReference = body['funding_reference']?.toString().trim() ?? '';
    final fiscalYear = int.tryParse(body['fiscal_year']?.toString() ?? '');
    final allocatedAmount = double.tryParse(
      body['allocated_amount']?.toString() ?? '',
    );
    final notes = body['notes']?.toString().trim();

    if (programId.isEmpty ||
        budgetSectionId.isEmpty ||
        fundingReference.isEmpty ||
        fiscalYear == null ||
        allocatedAmount == null) {
      throw const AppException(
        message:
            'Program, budget section, funding reference, fiscal year, and amount are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    if (allocatedAmount <= 0) {
      throw const AppException(
        message: 'Allocated amount must be greater than zero.',
        statusCode: 422,
        code: 'INVALID_ALLOCATED_AMOUNT',
      );
    }

    return _FundingPayload(
      programId: programId,
      budgetSectionId: budgetSectionId,
      fundingReference: fundingReference,
      fiscalYear: fiscalYear,
      allocatedAmount: allocatedAmount,
      notes: notes?.isEmpty == true ? null : notes,
    );
  }
}

class _FundingPayload {
  const _FundingPayload({
    required this.programId,
    required this.budgetSectionId,
    required this.fundingReference,
    required this.fiscalYear,
    required this.allocatedAmount,
    required this.notes,
  });

  final String programId;
  final String budgetSectionId;
  final String fundingReference;
  final int fiscalYear;
  final double allocatedAmount;
  final String? notes;
}
