import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/expenses_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';

class ExpensesController {
  const ExpensesController({
    required DatabaseService database,
    required ExpensesRepository expensesRepository,
    required AuditService auditService,
  }) : _database = database,
       _expensesRepository = expensesRepository,
       _auditService = auditService;

  final DatabaseService _database;
  final ExpensesRepository _expensesRepository;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final result = await _expensesRepository.list(
      _database.connection,
      search: request.url.queryParameters['search'] ?? '',
      reservationId: _emptyToNull(
        request.url.queryParameters['reservation_id'],
      ),
      programId: _emptyToNull(request.url.queryParameters['program_id']),
      budgetSectionId: _emptyToNull(
        request.url.queryParameters['budget_section_id'],
      ),
      dateFrom: _emptyToNull(request.url.queryParameters['date_from']),
      dateTo: _emptyToNull(request.url.queryParameters['date_to']),
      page: int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1,
      pageSize:
          int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10,
    );

    return jsonResponse(
      200,
      message: 'Expenses retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final payload = _validateCreateBody(body);

    final created = await _database.runTx((session) async {
      final reservation = await _expensesRepository.findReservationForExpense(
        session,
        payload.reservationId,
      );
      if (reservation == null) {
        throw const AppException(
          message: 'الحجز غير موجود.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      final status = reservation['workflow_status'].toString();
      if (status != 'approved') {
        throw const AppException(
          message: 'لا يمكن الصرف إلا على حجز معتمد.',
          statusCode: 422,
          code: 'RESERVATION_NOT_APPROVED',
        );
      }

      final reservedAmount = _toDouble(reservation['reserved_amount']);
      final spentAmount = _toDouble(reservation['spent_amount']);
      final remainingAmount = reservedAmount - spentAmount;
      // تعليق عربي: المقارنة بالفلس (أعداد صحيحة) لتفادي أخطاء التقريب في double،
      // فمثلاً صرف كامل المتبقي لا يُرفض بسبب فرق 0.0000001.
      if (_toFils(payload.amount) > _toFils(remainingAmount)) {
        throw AppException(
          message: 'مبلغ الصرف أكبر من المتبقي في الحجز.',
          statusCode: 422,
          code: 'EXPENSE_EXCEEDS_RESERVATION_REMAINING',
          details: {
            'reserved_amount': reservedAmount,
            'spent_amount': spentAmount,
            'remaining_amount': remainingAmount,
          },
        );
      }

      final duplicateExpenseNumber = await _expensesRepository
          .expenseNumberExists(session, payload.expenseNumber);
      if (duplicateExpenseNumber) {
        throw const AppException(
          message: 'رقم الصرف موجود مسبقاً.',
          statusCode: 409,
          code: 'EXPENSE_NUMBER_EXISTS',
        );
      }

      final expense = await _expensesRepository.create(
        session: session,
        reservationId: payload.reservationId,
        expenseNumber: payload.expenseNumber,
        amount: payload.amount,
        expenseDate: payload.expenseDate,
        paymentMethod: payload.paymentMethod,
        documentNumber: payload.documentNumber,
        documentDate: payload.documentDate,
        description: payload.description,
        createdBy: user.id,
      );

      // تعليق عربي: كل صرف مالي ينعكس فوراً في السجل المالي حتى تبقى التقارير مبنية على Ledger.
      await _expensesRepository.createLedgerTransaction(
        session: session,
        reservationId: payload.reservationId,
        expenseId: expense.id,
        fundingId: reservation['funding_id'].toString(),
        programId: reservation['program_id'].toString(),
        budgetSectionId: reservation['budget_section_id'].toString(),
        fiscalYearId: reservation['fiscal_year_id']?.toString(),
        budgetTypeId: reservation['budget_type_id']?.toString(),
        createdBy: user.id,
        amount: payload.amount,
        transactionType: 'expense_disbursement',
        direction: 'OUT',
        description:
            'Expense ${expense.expenseNumber} for reservation '
            '${reservation['reservation_number']}.',
      );

      final newSpentAmount = spentAmount + payload.amount;
      // تعليق عربي: عند الصرف من الحجز نغلق دورة الحجز مالياً.
      // إذا كان الصرف أقل من المحجوز، نحرر المتبقي من المحجوز فقط ولا نلمس التخصيص السنوي.
      await _expensesRepository.balanceReservationHold(
        session: session,
        reservationId: payload.reservationId,
        fundingId: reservation['funding_id'].toString(),
        programId: reservation['program_id'].toString(),
        budgetSectionId: reservation['budget_section_id'].toString(),
        fiscalYearId: reservation['fiscal_year_id']?.toString(),
        budgetTypeId: reservation['budget_type_id']?.toString(),
        createdBy: user.id,
        targetHoldAmount: newSpentAmount,
        description:
            'Release unused reservation hold after expense '
            '${expense.expenseNumber}.',
      );

      await _expensesRepository.updateReservationStatus(
        session: session,
        reservationId: payload.reservationId,
        status: 'completed',
        updatedBy: user.id,
        closedAt: DateTime.now().toUtc().toIso8601String(),
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'EXPENSE_CREATED',
        entityName: 'expenses',
        entityId: expense.id,
        description: 'Expense created and posted to ledger.',
        newValues: expense.toJson(),
      );

      return expense;
    });

    return jsonResponse(
      201,
      message: 'Expense created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> cancel(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final user = _requestUser(request);
    final reason = body['cancel_reason']?.toString().trim() ?? '';
    if (reason.isEmpty) {
      throw const AppException(
        message: 'سبب الإلغاء مطلوب.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final cancelled = await _database.runTx((session) async {
      final existing = await _expensesRepository.findById(session, id);
      if (existing == null) {
        throw const AppException(
          message: 'مستند الصرف غير موجود.',
          statusCode: 404,
          code: 'EXPENSE_NOT_FOUND',
        );
      }

      // تعليق عربي: هذا الاستعلام يقفل الحجز، ثم نعيد قراءة المستند بعد القفل حتى لا يُلغى
      // نفس المستند مرتين بالتزامن فتُعكس قيمته في الحركات المالية مرتين.
      final reservation = await _expensesRepository.findReservationForExpense(
        session,
        existing.reservationId,
      );
      final current = (await _expensesRepository.findById(session, id))!;
      if (current.expenseStatus == 'cancelled') {
        throw const AppException(
          message: 'مستند الصرف ملغى مسبقاً.',
          statusCode: 422,
          code: 'EXPENSE_ALREADY_CANCELLED',
        );
      }

      if (reservation == null) {
        throw const AppException(
          message: 'الحجز غير موجود.',
          statusCode: 404,
          code: 'RESERVATION_NOT_FOUND',
        );
      }

      if (reservation['workflow_status'].toString() == 'closed') {
        throw const AppException(
          message: 'لا يمكن إلغاء صرف على حجز مغلق.',
          statusCode: 422,
          code: 'RESERVATION_CLOSED',
        );
      }

      await _expensesRepository.cancel(
        session: session,
        id: id,
        reason: reason,
        cancelledBy: user.id,
      );

      await _expensesRepository.createLedgerTransaction(
        session: session,
        reservationId: current.reservationId,
        expenseId: current.id,
        fundingId: reservation['funding_id'].toString(),
        programId: reservation['program_id'].toString(),
        budgetSectionId: reservation['budget_section_id'].toString(),
        fiscalYearId: reservation['fiscal_year_id']?.toString(),
        budgetTypeId: reservation['budget_type_id']?.toString(),
        createdBy: user.id,
        amount: current.amount,
        transactionType: 'expense_reversal',
        direction: 'IN',
        description: 'Expense reversal for ${current.expenseNumber}.',
      );

      final reservedAmount = _toDouble(reservation['reserved_amount']);
      final spentAfterCancel =
          (_toDouble(reservation['spent_amount']) - current.amount).clamp(
            0,
            reservedAmount,
          );
      final targetHoldAfterCancel = spentAfterCancel > 0
          ? spentAfterCancel.toDouble()
          : reservedAmount;
      await _expensesRepository.balanceReservationHold(
        session: session,
        reservationId: current.reservationId,
        fundingId: reservation['funding_id'].toString(),
        programId: reservation['program_id'].toString(),
        budgetSectionId: reservation['budget_section_id'].toString(),
        fiscalYearId: reservation['fiscal_year_id']?.toString(),
        budgetTypeId: reservation['budget_type_id']?.toString(),
        createdBy: user.id,
        targetHoldAmount: targetHoldAfterCancel,
        description: 'Rebalance reservation hold after cancelling expense.',
      );

      final newStatus = spentAfterCancel > 0 ? 'completed' : 'approved';
      await _expensesRepository.updateReservationStatus(
        session: session,
        reservationId: current.reservationId,
        status: newStatus,
        updatedBy: user.id,
        clearClosedAt: newStatus == 'approved',
      );

      final updated = await _expensesRepository.findById(session, id);
      await _auditService.log(
        session: session,
        actor: user,
        action: 'EXPENSE_CANCELLED',
        entityName: 'expenses',
        entityId: id,
        description: 'Expense cancelled and ledger reversed.',
        oldValues: current.toJson(),
        newValues: updated?.toJson(),
      );

      return updated ?? current;
    });

    return jsonResponse(
      200,
      message: 'Expense cancelled successfully.',
      data: cancelled.toJson(),
    );
  }

  _ExpensePayload _validateCreateBody(Map<String, dynamic> body) {
    final reservationId = body['reservation_id']?.toString().trim() ?? '';
    final expenseNumber = body['expense_number']?.toString().trim() ?? '';
    final amount = double.tryParse(body['amount']?.toString() ?? '');
    final expenseDate = body['expense_date']?.toString().trim() ?? '';
    final paymentMethod = body['payment_method']?.toString().trim();
    final documentNumber = body['document_number']?.toString().trim();
    final documentDate = body['document_date']?.toString().trim();
    final description = body['description']?.toString().trim();

    if (reservationId.isEmpty ||
        expenseNumber.isEmpty ||
        amount == null ||
        expenseDate.isEmpty) {
      throw const AppException(
        message: 'الحجز ورقم الصرف والمبلغ وتاريخ الصرف مطلوبة.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }
    if (amount <= 0) {
      throw const AppException(
        message: 'مبلغ الصرف يجب أن يكون أكبر من صفر.',
        statusCode: 422,
        code: 'INVALID_EXPENSE_AMOUNT',
      );
    }
    // تعليق عربي: القاعدة تخزن NUMERIC(18,2)؛ نرفض الكسور الأدق بدل أن تُقرَّب بصمت عند الحفظ.
    if ((amount * 100 - _toFils(amount)).abs() > 1e-6) {
      throw const AppException(
        message: 'مبلغ الصرف يقبل منزلتين عشريتين كحد أقصى.',
        statusCode: 422,
        code: 'INVALID_EXPENSE_AMOUNT',
      );
    }

    return _ExpensePayload(
      reservationId: reservationId,
      expenseNumber: expenseNumber,
      amount: amount,
      expenseDate: expenseDate,
      paymentMethod: paymentMethod?.isEmpty == true ? null : paymentMethod,
      documentNumber: documentNumber?.isEmpty == true ? null : documentNumber,
      documentDate: documentDate?.isEmpty == true ? null : documentDate,
      description: description?.isEmpty == true ? null : description,
    );
  }

  RequestUser _requestUser(Request request) {
    final requestUser = request.context[requestUserContextKey] as RequestUser?;
    if (requestUser == null) {
      throw const AppException(
        message: 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }
    return requestUser;
  }

  String? _emptyToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  double _toDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '0') ?? 0;

  int _toFils(double value) => (value * 100).round();
}

class _ExpensePayload {
  const _ExpensePayload({
    required this.reservationId,
    required this.expenseNumber,
    required this.amount,
    required this.expenseDate,
    required this.paymentMethod,
    required this.documentNumber,
    required this.documentDate,
    required this.description,
  });

  final String reservationId;
  final String expenseNumber;
  final double amount;
  final String expenseDate;
  final String? paymentMethod;
  final String? documentNumber;
  final String? documentDate;
  final String? description;
}
