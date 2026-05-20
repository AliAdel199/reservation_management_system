import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/budget_sections_repository.dart';
import '../repositories/fundings_repository.dart';
import '../repositories/programs_repository.dart';
import '../repositories/reservations_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class ReservationsController {
  const ReservationsController({
    required DatabaseService database,
    required ReservationsRepository reservationsRepository,
    required ProgramsRepository programsRepository,
    required BudgetSectionsRepository budgetSectionsRepository,
    required FundingsRepository fundingsRepository,
    required AuditService auditService,
  }) : _database = database,
       _reservationsRepository = reservationsRepository,
       _programsRepository = programsRepository,
       _budgetSectionsRepository = budgetSectionsRepository,
       _fundingsRepository = fundingsRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final ReservationsRepository _reservationsRepository;
  final ProgramsRepository _programsRepository;
  final BudgetSectionsRepository _budgetSectionsRepository;
  final FundingsRepository _fundingsRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final status = request.url.queryParameters['status'];
    final programId = request.url.queryParameters['program_id'];
    final budgetSectionId = request.url.queryParameters['budget_section_id'];
    final fundingId = request.url.queryParameters['funding_id'];
    final executionStatus = request.url.queryParameters['execution_status'];
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;

    final result = await _reservationsRepository.list(
      _database.connection,
      search: search,
      status: status?.isEmpty == true ? null : status,
      programId: programId?.isEmpty == true ? null : programId,
      budgetSectionId: budgetSectionId?.isEmpty == true
          ? null
          : budgetSectionId,
      fundingId: fundingId?.isEmpty == true ? null : fundingId,
      executionStatus: executionStatus?.isEmpty == true
          ? null
          : executionStatus,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Reservations retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final created = await _database.runTx((session) async {
      await _budgetSectionsRepository.ensurePostable(
        session,
        payload.budgetSectionId,
      );

      final fundingId = await _resolveFundingId(
        session,
        createdBy: user.id,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingId: payload.fundingId,
      );

      final duplicate = await _reservationsRepository.findByNumber(
        session,
        payload.reservationNumber,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Reservation number already exists.',
          statusCode: 409,
          code: 'RESERVATION_NUMBER_EXISTS',
        );
      }

      final reservation = await _reservationsRepository.create(
        session: session,
        reservationNumber: payload.reservationNumber,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingId: fundingId,
        title: payload.title,
        description: payload.description,
        beneficiary: payload.beneficiary,
        executionNote: payload.executionNote,
        requesterDepartment: payload.requesterDepartment,
        contactPhone: payload.contactPhone,
        reservedAmount: payload.reservedAmount,
        reservationDate: payload.reservationDate,
        createdBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_CREATED',
        entityName: 'reservations',
        entityId: reservation.id,
        description: 'Reservation created in draft state.',
        newValues: reservation.toJson(),
      );

      return reservation;
    });

    return jsonResponse(
      201,
      message: 'Reservation created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateBody(body);

    final updated = await _database.runTx((session) async {
      final current = await _reservationsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Reservation not found.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (current.workflowStatus == 'approved' ||
          current.workflowStatus == 'partially_spent' ||
          current.workflowStatus == 'completed' ||
          current.workflowStatus == 'cancelled') {
        throw const AppException(
          message: 'Only draft or under review reservations can be edited.',
          statusCode: 422,
          code: 'RESERVATION_NOT_EDITABLE',
        );
      }

      await _budgetSectionsRepository.ensurePostable(
        session,
        payload.budgetSectionId,
      );

      final fundingId = await _resolveFundingId(
        session,
        createdBy: user.id,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingId: payload.fundingId,
      );

      final duplicate = await _reservationsRepository.findByNumber(
        session,
        payload.reservationNumber,
        ignoreId: id,
      );
      if (duplicate != null) {
        throw const AppException(
          message: 'Reservation number already exists.',
          statusCode: 409,
          code: 'RESERVATION_NUMBER_EXISTS',
        );
      }

      final reservation = await _reservationsRepository.updateDraft(
        session: session,
        id: id,
        reservationNumber: payload.reservationNumber,
        programId: payload.programId,
        budgetSectionId: payload.budgetSectionId,
        fundingId: fundingId,
        title: payload.title,
        description: payload.description,
        beneficiary: payload.beneficiary,
        executionNote: payload.executionNote,
        requesterDepartment: payload.requesterDepartment,
        contactPhone: payload.contactPhone,
        reservedAmount: payload.reservedAmount,
        reservationDate: payload.reservationDate,
        updatedBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_UPDATED',
        entityName: 'reservations',
        entityId: reservation.id,
        description: 'Reservation updated.',
        oldValues: current.toJson(),
        newValues: reservation.toJson(),
      );

      return reservation;
    });

    return jsonResponse(
      200,
      message: 'Reservation updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> submitForReview(Request request, String id) async {
    final user = _requestUser(request);
    final updated = await _database.runTx((session) async {
      final current = await _reservationsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Reservation not found.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (current.workflowStatus != 'draft') {
        throw const AppException(
          message: 'Only draft reservations can be submitted for review.',
          statusCode: 422,
          code: 'INVALID_RESERVATION_STATUS',
        );
      }

      final reservation = await _reservationsRepository.changeStatus(
        session: session,
        id: id,
        status: 'under_review',
        updatedBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_SUBMITTED',
        entityName: 'reservations',
        entityId: id,
        description: 'Reservation submitted for review.',
        oldValues: current.toJson(),
        newValues: reservation.toJson(),
      );

      return reservation;
    });

    return jsonResponse(
      200,
      message: 'Reservation submitted for review successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> approve(Request request, String id) async {
    final user = _requestUser(request);
    final updated = await _database.runTx((session) async {
      final current = await _reservationsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Reservation not found.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (current.workflowStatus != 'draft' &&
          current.workflowStatus != 'under_review') {
        throw const AppException(
          message: 'Only reserved reservations can be approved.',
          statusCode: 422,
          code: 'INVALID_RESERVATION_STATUS',
        );
      }

      // تعليق عربي: ملف المتابعة المعتمد لدى المؤسسة يسمح بظهور القابل للتصرف بالسالب.
      // لذلك لا نمنع اعتماد الحجز عند تجاوز التخصيص، بل ينعكس التجاوز في التقارير والتنبيهات.
      final reservation = await _reservationsRepository.changeStatus(
        session: session,
        id: id,
        status: 'approved',
        approvedAt: DateTime.now().toUtc().toIso8601String(),
        updatedBy: user.id,
      );

      await _reservationsRepository.createLedgerTransaction(
        session: session,
        reservationId: reservation.id,
        fundingId: reservation.fundingId,
        programId: reservation.programId,
        budgetSectionId: reservation.budgetSectionId,
        createdBy: user.id,
        amount: reservation.reservedAmount,
        transactionType: 'reservation_hold',
        description: 'Reservation hold for ${reservation.reservationNumber}.',
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_APPROVED',
        entityName: 'reservations',
        entityId: id,
        description: 'Reservation approved and funds held.',
        oldValues: current.toJson(),
        newValues: reservation.toJson(),
      );

      return reservation;
    });

    return jsonResponse(
      200,
      message: 'Reservation approved successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> cancel(Request request, String id) async {
    final user = _requestUser(request);
    final updated = await _database.runTx((session) async {
      final current = await _reservationsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Reservation not found.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (current.workflowStatus == 'cancelled' ||
          current.workflowStatus == 'completed' ||
          current.workflowStatus == 'fully_spent' ||
          current.workflowStatus == 'partially_spent') {
        throw const AppException(
          message: 'Spent or cancelled reservations cannot be cancelled.',
          statusCode: 422,
          code: 'INVALID_RESERVATION_STATUS',
        );
      }

      final hasActiveExpenses = await _reservationsRepository.hasActiveExpenses(
        session,
        id,
      );
      if (hasActiveExpenses) {
        throw const AppException(
          message: 'Reservation has active expenses and cannot be cancelled.',
          statusCode: 422,
          code: 'RESERVATION_HAS_EXPENSES',
        );
      }

      final reservation = await _reservationsRepository.changeStatus(
        session: session,
        id: id,
        status: 'cancelled',
        cancelledAt: DateTime.now().toUtc().toIso8601String(),
        updatedBy: user.id,
      );

      if (current.workflowStatus == 'approved') {
        await _reservationsRepository.createLedgerTransaction(
          session: session,
          reservationId: reservation.id,
          fundingId: reservation.fundingId,
          programId: reservation.programId,
          budgetSectionId: reservation.budgetSectionId,
          createdBy: user.id,
          amount: reservation.reservedAmount,
          transactionType: 'reservation_release',
          description:
              'Reservation release for cancelled reservation ${reservation.reservationNumber}.',
        );
      }

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_CANCELLED',
        entityName: 'reservations',
        entityId: id,
        description: 'Reservation cancelled.',
        oldValues: current.toJson(),
        newValues: reservation.toJson(),
      );

      return reservation;
    });

    return jsonResponse(
      200,
      message: 'Reservation cancelled successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> delete(Request request, String id) async {
    final user = _requestUser(request);
    await _database.runTx((session) async {
      final current = await _reservationsRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'Reservation not found.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (current.workflowStatus != 'cancelled') {
        throw const AppException(
          message: 'Only cancelled reservations can be deleted.',
          statusCode: 422,
          code: 'RESERVATION_DELETE_REQUIRES_CANCELLED',
        );
      }

      final hasActiveExpenses = await _reservationsRepository.hasActiveExpenses(
        session,
        id,
      );
      if (hasActiveExpenses) {
        throw const AppException(
          message: 'Reservation has active expenses and cannot be deleted.',
          statusCode: 422,
          code: 'RESERVATION_HAS_EXPENSES',
        );
      }

      await _reservationsRepository.softDelete(
        session: session,
        id: id,
        deletedBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'RESERVATION_DELETED',
        entityName: 'reservations',
        entityId: id,
        description: 'Cancelled reservation soft deleted.',
        oldValues: current.toJson(),
      );
    });

    return jsonResponse(200, message: 'Reservation deleted successfully.');
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

  Future<String> _resolveFundingId(
    dynamic session, {
    required String createdBy,
    required String programId,
    required String budgetSectionId,
    required String fundingId,
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
        message: 'الباب المختار لا يتبع البرنامج المحدد.',
        statusCode: 422,
        code: 'INVALID_BUDGET_SECTION_MAPPING',
      );
    }

    if (fundingId.isEmpty) {
      final funding = await _fundingsRepository.ensureAnnualSectionFunding(
        session: session,
        budgetSectionId: budgetSectionId,
        createdBy: createdBy,
      );
      return funding.id;
    }

    final funding = await _fundingsRepository.findById(session, fundingId);
    if (funding == null) {
      throw const AppException(
        message: 'Funding not found.',
        statusCode: 404,
        code: 'FUNDING_NOT_FOUND',
      );
    }

    if (funding.programId != programId ||
        funding.budgetSectionId != budgetSectionId) {
      throw const AppException(
        message: 'Program, budget section, and funding are not aligned.',
        statusCode: 422,
        code: 'INVALID_FUNDING_MAPPING',
      );
    }

    return funding.id;
  }

  _ReservationPayload _validateBody(Map<String, dynamic> body) {
    final reservationNumber =
        body['reservation_number']?.toString().trim() ?? '';
    final programId = body['program_id']?.toString().trim() ?? '';
    final budgetSectionId = body['budget_section_id']?.toString().trim() ?? '';
    final fundingId = body['funding_id']?.toString().trim() ?? '';
    final description = body['description']?.toString().trim();
    final beneficiary =
        body['beneficiary']?.toString().trim() ??
        body['beneficiary_name']?.toString().trim();
    final executionNote =
        body['execution_note']?.toString().trim() ??
        body['execution_notes']?.toString().trim();
    final requesterDepartment =
        body['requester_department']?.toString().trim() ??
        body['department']?.toString().trim();
    final contactPhone =
        body['contact_phone']?.toString().trim() ??
        body['phone']?.toString().trim();
    final reservedAmount = double.tryParse(
      body['reserved_amount']?.toString() ?? '',
    );
    final reservationDate = body['reservation_date']?.toString().trim() ?? '';
    final title = (body['title']?.toString().trim().isNotEmpty == true)
        ? body['title']!.toString().trim()
        : (beneficiary ?? '');

    // تعليق عربي: القسم ورقم الهاتف معلومات مساندة وليست إلزامية في سجل الحجوزات.
    final missingFields = <String>[
      if (reservationNumber.isEmpty) 'رقم الحجز',
      if (programId.isEmpty) 'البرنامج',
      if (budgetSectionId.isEmpty) 'الباب',
      if (title.isEmpty || beneficiary == null || beneficiary.isEmpty)
        'الجهة المحجوز لها',
      if (reservedAmount == null) 'المبلغ',
      if (reservationDate.isEmpty) 'تاريخ الحجز',
    ];

    if (missingFields.isNotEmpty) {
      throw AppException(
        message: 'الحقول المطلوبة ناقصة: ${missingFields.join('، ')}.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final validReservedAmount = reservedAmount!;
    if (validReservedAmount <= 0) {
      throw const AppException(
        message: 'Reserved amount must be greater than zero.',
        statusCode: 422,
        code: 'INVALID_RESERVED_AMOUNT',
      );
    }

    return _ReservationPayload(
      reservationNumber: reservationNumber,
      programId: programId,
      budgetSectionId: budgetSectionId,
      fundingId: fundingId,
      title: title,
      description: description?.isEmpty == true ? null : description,
      beneficiary: beneficiary,
      executionNote: executionNote?.isEmpty == true ? null : executionNote,
      requesterDepartment: requesterDepartment?.isEmpty == true
          ? null
          : requesterDepartment,
      contactPhone: contactPhone?.isEmpty == true ? null : contactPhone,
      reservedAmount: validReservedAmount,
      reservationDate: reservationDate,
    );
  }
}

class _ReservationPayload {
  const _ReservationPayload({
    required this.reservationNumber,
    required this.programId,
    required this.budgetSectionId,
    required this.fundingId,
    required this.title,
    required this.description,
    required this.beneficiary,
    required this.executionNote,
    required this.requesterDepartment,
    required this.contactPhone,
    required this.reservedAmount,
    required this.reservationDate,
  });

  final String reservationNumber;
  final String programId;
  final String budgetSectionId;
  final String fundingId;
  final String title;
  final String? description;
  final String? beneficiary;
  final String? executionNote;
  final String? requesterDepartment;
  final String? contactPhone;
  final double reservedAmount;
  final String reservationDate;
}
