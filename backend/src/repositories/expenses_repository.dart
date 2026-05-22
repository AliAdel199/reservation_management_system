import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/expense.dart';
import '../models/paged_result.dart';

class ExpensesRepository {
  const ExpensesRepository();

  static const _uuid = Uuid();

  Future<PagedResult<Expense>> list(
    Session session, {
    required String search,
    required String? reservationId,
    required String? programId,
    required String? budgetSectionId,
    required String? dateFrom,
    required String? dateTo,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;

    final countResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM expenses e
        INNER JOIN reservations r ON r.id = e.reservation_id
        WHERE e.deleted_at IS NULL
          AND (@reservation_id = '' OR e.reservation_id = @reservation_id::uuid)
          AND (@program_id = '' OR r.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR r.budget_section_id = @budget_section_id::uuid)
          AND (@date_from = '' OR e.expense_date >= @date_from::date)
          AND (@date_to = '' OR e.expense_date <= @date_to::date)
          AND (
            @search = ''
            OR LOWER(e.expense_number) LIKE LOWER(@pattern)
            OR LOWER(r.reservation_number) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(e.description, e.notes, '')) LIKE LOWER(@pattern)
          )
      '''),
      parameters: {
        'reservation_id': reservationId ?? '',
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'date_from': dateFrom ?? '',
        'date_to': dateTo ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
      },
    );

    final result = await session.execute(
      Sql.named('''
        SELECT
          e.id,
          e.reservation_id,
          r.reservation_number,
          p.name AS program_name,
          bs.name AS budget_section_name,
          e.expense_number,
          e.amount,
          e.expense_status::text AS expense_status,
          e.expense_date,
          e.payment_method,
          e.document_number,
          e.document_date,
          COALESCE(e.description, e.notes) AS description,
          e.created_at,
          e.cancelled_at,
          e.cancel_reason
        FROM expenses e
        INNER JOIN reservations r ON r.id = e.reservation_id
        INNER JOIN programs p ON p.id = r.program_id
        INNER JOIN budget_sections bs ON bs.id = r.budget_section_id
        WHERE e.deleted_at IS NULL
          AND (@reservation_id = '' OR e.reservation_id = @reservation_id::uuid)
          AND (@program_id = '' OR r.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR r.budget_section_id = @budget_section_id::uuid)
          AND (@date_from = '' OR e.expense_date >= @date_from::date)
          AND (@date_to = '' OR e.expense_date <= @date_to::date)
          AND (
            @search = ''
            OR LOWER(e.expense_number) LIKE LOWER(@pattern)
            OR LOWER(r.reservation_number) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(e.description, e.notes, '')) LIKE LOWER(@pattern)
          )
        ORDER BY e.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'reservation_id': reservationId ?? '',
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'date_from': dateFrom ?? '',
        'date_to': dateTo ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    return PagedResult<Expense>(
      items: result.map((row) => Expense.fromRow(row.toColumnMap())).toList(),
      total: int.parse(countResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Expense?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          e.id,
          e.reservation_id,
          r.reservation_number,
          p.name AS program_name,
          bs.name AS budget_section_name,
          e.expense_number,
          e.amount,
          e.expense_status::text AS expense_status,
          e.expense_date,
          e.payment_method,
          e.document_number,
          e.document_date,
          COALESCE(e.description, e.notes) AS description,
          e.created_at,
          e.cancelled_at,
          e.cancel_reason
        FROM expenses e
        INNER JOIN reservations r ON r.id = e.reservation_id
        INNER JOIN programs p ON p.id = r.program_id
        INNER JOIN budget_sections bs ON bs.id = r.budget_section_id
        WHERE e.id = @id::uuid
        LIMIT 1
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;
    return Expense.fromRow(result.first.toColumnMap());
  }

  Future<Map<String, dynamic>?> findReservationForExpense(
    Session session,
    String reservationId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          r.id,
          r.reservation_number,
          r.program_id,
          r.budget_section_id,
          r.funding_id,
          r.fiscal_year_id,
          r.budget_type_id,
          r.reserved_amount,
          r.workflow_status::text AS workflow_status,
          COALESCE(SUM(
            CASE
              WHEN e.expense_status::text <> 'cancelled'
                   AND e.deleted_at IS NULL THEN e.amount
              ELSE 0
            END
          ), 0) AS spent_amount
        FROM reservations r
        LEFT JOIN expenses e ON e.reservation_id = r.id
        WHERE r.id = @reservation_id::uuid
          AND r.deleted_at IS NULL
        GROUP BY r.id
        LIMIT 1
      '''),
      parameters: {'reservation_id': reservationId},
    );

    if (result.isEmpty) return null;
    return result.first.toColumnMap();
  }

  Future<Expense> create({
    required Session session,
    required String reservationId,
    required String expenseNumber,
    required double amount,
    required String expenseDate,
    required String? paymentMethod,
    required String? documentNumber,
    required String? documentDate,
    required String? description,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO expenses (
          id,
          reservation_id,
          expense_number,
          amount,
          expense_status,
          expense_date,
          payment_method,
          document_number,
          document_date,
          description,
          notes,
          created_by
        ) VALUES (
          @id,
          @reservation_id::uuid,
          @expense_number,
          @amount,
          'paid',
          @expense_date::date,
          @payment_method,
          @document_number,
          NULLIF(@document_date, '')::date,
          @description,
          @description,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'reservation_id': reservationId,
        'expense_number': expenseNumber,
        'amount': amount,
        'expense_date': expenseDate,
        'payment_method': paymentMethod,
        'document_number': documentNumber,
        'document_date': documentDate ?? '',
        'description': description,
        'created_by': createdBy,
      },
    );

    final expense = await findById(session, id);
    if (expense == null) {
      throw const AppException(
        message: 'Failed to load created expense.',
        statusCode: 500,
        code: 'EXPENSE_CREATE_FAILED',
      );
    }
    return expense;
  }

  Future<void> createLedgerTransaction({
    required Session session,
    required String reservationId,
    required String expenseId,
    required String fundingId,
    required String programId,
    required String budgetSectionId,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String createdBy,
    required double amount,
    required String transactionType,
    required String direction,
    required String description,
  }) async {
    await session.execute(
      Sql.named('''
        INSERT INTO financial_transactions (
          id,
          transaction_number,
          transaction_type,
          reference_type,
          amount,
          direction,
          description,
          reference_table,
          reference_id,
          program_id,
          budget_section_id,
          section_id,
          funding_id,
          reservation_id,
          expense_id,
          fiscal_year_id,
          budget_type_id,
          created_by
        ) VALUES (
          @id,
          @transaction_number,
          @transaction_type::transaction_type,
          'expenses',
          @amount,
          @direction::transaction_direction,
          @description,
          'expenses',
          @reference_id::uuid,
          @program_id::uuid,
          @budget_section_id::uuid,
          @budget_section_id::uuid,
          @funding_id::uuid,
          @reservation_id::uuid,
          @expense_id::uuid,
          NULLIF(@fiscal_year_id, '')::uuid,
          NULLIF(@budget_type_id, '')::uuid,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            'EX-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': transactionType,
        'amount': amount,
        'direction': direction,
        'description': description,
        'reference_id': expenseId,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'reservation_id': reservationId,
        'expense_id': expenseId,
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'created_by': createdBy,
      },
    );
  }

  Future<void> balanceReservationHold({
    required Session session,
    required String reservationId,
    required String fundingId,
    required String programId,
    required String budgetSectionId,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String createdBy,
    required double targetHoldAmount,
    required String description,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT COALESCE(SUM(
          CASE
            WHEN transaction_type::text = 'reservation_hold' THEN amount
            WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
            ELSE 0
          END
        ), 0) AS current_hold
        FROM financial_transactions
        WHERE reservation_id = @reservation_id::uuid
      '''),
      parameters: {'reservation_id': reservationId},
    );

    final currentHold = _toDouble(result.first[0]);
    final difference = currentHold - targetHoldAmount;
    if (difference.abs() < 0.01) return;

    final isRelease = difference > 0;
    final amount = difference.abs();
    await session.execute(
      Sql.named('''
        INSERT INTO financial_transactions (
          id,
          transaction_number,
          transaction_type,
          reference_type,
          amount,
          direction,
          description,
          reference_table,
          reference_id,
          program_id,
          budget_section_id,
          section_id,
          funding_id,
          reservation_id,
          fiscal_year_id,
          budget_type_id,
          created_by
        ) VALUES (
          @id,
          @transaction_number,
          @transaction_type::transaction_type,
          'reservations',
          @amount,
          @direction::transaction_direction,
          @description,
          'reservations',
          @reservation_id::uuid,
          @program_id::uuid,
          @budget_section_id::uuid,
          @budget_section_id::uuid,
          @funding_id::uuid,
          @reservation_id::uuid,
          NULLIF(@fiscal_year_id, '')::uuid,
          NULLIF(@budget_type_id, '')::uuid,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            '${isRelease ? 'RR' : 'RH'}-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': isRelease
            ? 'reservation_release'
            : 'reservation_hold',
        'direction': isRelease ? 'IN' : 'OUT',
        'amount': amount,
        'description': description,
        'reservation_id': reservationId,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'created_by': createdBy,
      },
    );
  }

  Future<void> updateReservationStatus({
    required Session session,
    required String reservationId,
    required String status,
    required String updatedBy,
    String? closedAt,
    bool clearClosedAt = false,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE reservations
        SET workflow_status = @status::reservation_status,
            closed_at = CASE
              WHEN @clear_closed_at THEN NULL
              ELSE COALESCE(NULLIF(@closed_at, '')::timestamptz, closed_at)
            END,
            updated_by = @updated_by::uuid
        WHERE id = @reservation_id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {
        'reservation_id': reservationId,
        'status': status,
        'updated_by': updatedBy,
        'closed_at': closedAt ?? '',
        'clear_closed_at': clearClosedAt,
      },
    );
  }

  Future<void> cancel({
    required Session session,
    required String id,
    required String reason,
    required String cancelledBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE expenses
        SET expense_status = 'cancelled',
            cancelled_by = @cancelled_by::uuid,
            cancelled_at = NOW(),
            cancel_reason = @cancel_reason
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'cancelled_by': cancelledBy,
        'cancel_reason': reason,
      },
    );
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
