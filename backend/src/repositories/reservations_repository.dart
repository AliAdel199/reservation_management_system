import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/paged_result.dart';
import '../models/reservation.dart';

class ReservationsRepository {
  const ReservationsRepository();

  static const _uuid = Uuid();

  static const _reservationFinancialCte = '''
    WITH allocation_fallback AS (
      SELECT
        f.budget_section_id AS section_id,
        COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
      FROM fundings f
      WHERE f.deleted_at IS NULL
      GROUP BY f.budget_section_id
    ),
    section_allocations AS (
      SELECT
        bs.id AS section_id,
        CASE
          -- تعليق عربي: التخصيص السنوي للباب هو مصدر منع تجاوز الحجز.
          -- التمويل الشهري معلّق حالياً لحين تثبيت فكرته.
          WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
          ELSE COALESCE(af.total_allocation, 0)
        END AS allocated_amount
      FROM budget_sections bs
      LEFT JOIN allocation_fallback af ON af.section_id = bs.id
      WHERE bs.deleted_at IS NULL
    ),
    section_reserved AS (
      SELECT
        COALESCE(ft.section_id, ft.budget_section_id) AS section_id,
        COALESCE(SUM(
          CASE
            WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
            WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
            ELSE 0
          END
        ), 0) AS total_reserved
      FROM financial_transactions ft
      WHERE COALESCE(ft.section_id, ft.budget_section_id) IS NOT NULL
      GROUP BY COALESCE(ft.section_id, ft.budget_section_id)
    ),
    section_balances AS (
      SELECT
        sa.section_id,
        COALESCE(sa.allocated_amount, 0) - COALESCE(sr.total_reserved, 0)
          AS available_balance
      FROM section_allocations sa
      LEFT JOIN section_reserved sr ON sr.section_id = sa.section_id
    ),
    expense_totals AS (
      SELECT
        e.reservation_id,
        COALESCE(SUM(
          CASE
            WHEN e.expense_status::text <> 'cancelled'
                 AND e.deleted_at IS NULL THEN e.amount
            ELSE 0
          END
        ), 0) AS spent_amount
      FROM expenses e
      GROUP BY e.reservation_id
    )
  ''';

  Future<PagedResult<Reservation>> list(
    Session session, {
    required String search,
    required String? status,
    required String? programId,
    required String? budgetSectionId,
    required String? fundingId,
    required String? executionStatus,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        $_reservationFinancialCte
        SELECT COUNT(*)
        FROM reservations r
        LEFT JOIN expense_totals et ON et.reservation_id = r.id
        WHERE
          r.deleted_at IS NULL
          AND (
            @status = ''
            OR (@status = 'reserved' AND r.workflow_status::text IN ('draft', 'under_review'))
            OR (@status = 'spent' AND r.workflow_status::text IN ('partially_spent', 'fully_spent', 'completed'))
            OR r.workflow_status::text = @status
          )
          AND (@program_id = '' OR r.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR r.budget_section_id = @budget_section_id::uuid)
          AND (@funding_id = '' OR r.funding_id = @funding_id::uuid)
          AND (
            @execution_status = ''
            OR (
              CASE
                WHEN r.workflow_status::text = 'cancelled' THEN 'cancelled'
                WHEN COALESCE(et.spent_amount, 0) <= 0 THEN 'not_executed'
                WHEN COALESCE(et.spent_amount, 0) >= r.reserved_amount THEN 'executed'
                ELSE 'partially_executed'
              END
            ) = @execution_status
          )
          AND (
            @search = ''
            OR LOWER(r.reservation_number) LIKE LOWER(@pattern)
            OR LOWER(r.title) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.beneficiary, '')) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.requester_department, '')) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.contact_phone, '')) LIKE LOWER(@pattern)
          )
      '''),
      parameters: {
        'status': status ?? '',
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'funding_id': fundingId ?? '',
        'execution_status': executionStatus ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
      },
    );

    final itemsResult = await session.execute(
      Sql.named('''
        $_reservationFinancialCte
        SELECT
          r.id,
          r.reservation_number,
          r.program_id,
          p.code AS program_code,
          p.name AS program_name,
          r.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          r.funding_id,
          f.funding_reference,
          r.title,
          r.description,
          r.beneficiary,
          r.execution_note,
          r.requester_department,
          r.contact_phone,
          r.reserved_amount,
          r.workflow_status::text AS workflow_status,
          r.reservation_date,
          r.created_at,
          r.approved_at,
          r.cancelled_at,
          r.closed_at,
          COALESCE(sb.available_balance, 0) AS funding_available_balance,
          COALESCE(et.spent_amount, 0) AS spent_amount,
          GREATEST(r.reserved_amount - COALESCE(et.spent_amount, 0), 0) AS remaining_amount,
          CASE
            WHEN r.workflow_status::text = 'cancelled' THEN 'cancelled'
            WHEN COALESCE(et.spent_amount, 0) <= 0 THEN 'not_executed'
            WHEN COALESCE(et.spent_amount, 0) >= r.reserved_amount THEN 'executed'
            ELSE 'partially_executed'
          END AS execution_status
        FROM reservations r
        INNER JOIN programs p ON p.id = r.program_id
        INNER JOIN budget_sections bs ON bs.id = r.budget_section_id
        INNER JOIN fundings f ON f.id = r.funding_id
        LEFT JOIN section_balances sb ON sb.section_id = r.budget_section_id
        LEFT JOIN expense_totals et ON et.reservation_id = r.id
        WHERE
          r.deleted_at IS NULL
          AND (
            @status = ''
            OR (@status = 'reserved' AND r.workflow_status::text IN ('draft', 'under_review'))
            OR (@status = 'spent' AND r.workflow_status::text IN ('partially_spent', 'fully_spent', 'completed'))
            OR r.workflow_status::text = @status
          )
          AND (@program_id = '' OR r.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR r.budget_section_id = @budget_section_id::uuid)
          AND (@funding_id = '' OR r.funding_id = @funding_id::uuid)
          AND (
            @execution_status = ''
            OR (
              CASE
                WHEN r.workflow_status::text = 'cancelled' THEN 'cancelled'
                WHEN COALESCE(et.spent_amount, 0) <= 0 THEN 'not_executed'
                WHEN COALESCE(et.spent_amount, 0) >= r.reserved_amount THEN 'executed'
                ELSE 'partially_executed'
              END
            ) = @execution_status
          )
          AND (
            @search = ''
            OR LOWER(r.reservation_number) LIKE LOWER(@pattern)
            OR LOWER(r.title) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.beneficiary, '')) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.requester_department, '')) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(r.contact_phone, '')) LIKE LOWER(@pattern)
          )
        ORDER BY r.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'status': status ?? '',
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'funding_id': fundingId ?? '',
        'execution_status': executionStatus ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    return PagedResult<Reservation>(
      items: itemsResult
          .map((row) => Reservation.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Reservation?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        $_reservationFinancialCte
        SELECT
          r.id,
          r.reservation_number,
          r.program_id,
          p.code AS program_code,
          p.name AS program_name,
          r.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          r.funding_id,
          f.funding_reference,
          r.title,
          r.description,
          r.beneficiary,
          r.execution_note,
          r.requester_department,
          r.contact_phone,
          r.reserved_amount,
          r.workflow_status::text AS workflow_status,
          r.reservation_date,
          r.created_at,
          r.approved_at,
          r.cancelled_at,
          r.closed_at,
          COALESCE(sb.available_balance, 0) AS funding_available_balance,
          COALESCE(et.spent_amount, 0) AS spent_amount,
          GREATEST(r.reserved_amount - COALESCE(et.spent_amount, 0), 0) AS remaining_amount,
          CASE
            WHEN r.workflow_status::text = 'cancelled' THEN 'cancelled'
            WHEN COALESCE(et.spent_amount, 0) <= 0 THEN 'not_executed'
            WHEN COALESCE(et.spent_amount, 0) >= r.reserved_amount THEN 'executed'
            ELSE 'partially_executed'
          END AS execution_status
        FROM reservations r
        INNER JOIN programs p ON p.id = r.program_id
        INNER JOIN budget_sections bs ON bs.id = r.budget_section_id
        INNER JOIN fundings f ON f.id = r.funding_id
        LEFT JOIN section_balances sb ON sb.section_id = r.budget_section_id
        LEFT JOIN expense_totals et ON et.reservation_id = r.id
        WHERE r.id = @id::uuid
          AND r.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;
    return Reservation.fromRow(result.first.toColumnMap());
  }

  Future<Reservation?> findByNumber(
    Session session,
    String reservationNumber, {
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        $_reservationFinancialCte
        SELECT
          r.id,
          r.reservation_number,
          r.program_id,
          p.code AS program_code,
          p.name AS program_name,
          r.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          r.funding_id,
          f.funding_reference,
          r.title,
          r.description,
          r.beneficiary,
          r.execution_note,
          r.requester_department,
          r.contact_phone,
          r.reserved_amount,
          r.workflow_status::text AS workflow_status,
          r.reservation_date,
          r.created_at,
          r.approved_at,
          r.cancelled_at,
          r.closed_at,
          COALESCE(sb.available_balance, 0) AS funding_available_balance,
          COALESCE(et.spent_amount, 0) AS spent_amount,
          GREATEST(r.reserved_amount - COALESCE(et.spent_amount, 0), 0) AS remaining_amount,
          CASE
            WHEN r.workflow_status::text = 'cancelled' THEN 'cancelled'
            WHEN COALESCE(et.spent_amount, 0) <= 0 THEN 'not_executed'
            WHEN COALESCE(et.spent_amount, 0) >= r.reserved_amount THEN 'executed'
            ELSE 'partially_executed'
          END AS execution_status
        FROM reservations r
        INNER JOIN programs p ON p.id = r.program_id
        INNER JOIN budget_sections bs ON bs.id = r.budget_section_id
        INNER JOIN fundings f ON f.id = r.funding_id
        LEFT JOIN section_balances sb ON sb.section_id = r.budget_section_id
        LEFT JOIN expense_totals et ON et.reservation_id = r.id
        WHERE LOWER(r.reservation_number) = LOWER(@reservation_number)
          AND (@ignore_id = '' OR r.id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {
        'reservation_number': reservationNumber,
        'ignore_id': ignoreId ?? '',
      },
    );

    if (result.isEmpty) return null;
    return Reservation.fromRow(result.first.toColumnMap());
  }

  Future<double> getFundingAvailableBalance(
    Session session,
    String fundingId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        SELECT COALESCE(SUM(
          CASE
            WHEN ft.transaction_type = 'allocation' THEN ft.amount
            WHEN ft.transaction_type = 'allocation_reversal' THEN -ft.amount
            WHEN ft.transaction_type = 'adjustment_increase' THEN ft.amount
            WHEN ft.transaction_type = 'adjustment_decrease' THEN -ft.amount
            WHEN ft.transaction_type = 'reservation_hold' THEN -ft.amount
            WHEN ft.transaction_type = 'reservation_release' THEN ft.amount
            WHEN ft.transaction_type = 'expense_disbursement' THEN -ft.amount
            WHEN ft.transaction_type = 'expense_reversal' THEN ft.amount
            ELSE 0
          END
        ), 0) AS available_balance
        FROM financial_transactions ft
        WHERE ft.funding_id = @funding_id::uuid
      '''),
      parameters: {'funding_id': fundingId},
    );

    final value = result.first[0];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<double> getSectionAvailableBalance(
    Session session,
    String budgetSectionId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        WITH target_section AS (
          SELECT
            bs.id,
            bs.fiscal_year_id,
            bs.budget_type_id,
            bs.program_id,
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE(af.total_allocation, 0)
            END AS legacy_section_allocation
          FROM budget_sections bs
          LEFT JOIN (
            SELECT
              f.budget_section_id AS section_id,
              COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
            FROM fundings f
            WHERE f.deleted_at IS NULL
            GROUP BY f.budget_section_id
          ) af ON af.section_id = bs.id
          WHERE bs.id = @budget_section_id::uuid
            AND bs.deleted_at IS NULL
          LIMIT 1
        ),
        section_allocation AS (
          SELECT
            -- تعليق عربي: نفس معادلة التقارير حتى لا يختلف منع الحجز عن الأرقام المعروضة.
            ts.legacy_section_allocation AS allocated_amount
          FROM target_section ts
        ),
        section_reserved AS (
          SELECT
            COALESCE(SUM(
              CASE
                WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
                WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
                ELSE 0
              END
            ), 0) AS total_reserved
          FROM financial_transactions ft
          WHERE COALESCE(ft.section_id, ft.budget_section_id) = @budget_section_id::uuid
        )
        SELECT
          COALESCE(sa.allocated_amount, 0) - COALESCE(sr.total_reserved, 0)
            AS available_balance
        FROM section_allocation sa
        CROSS JOIN section_reserved sr
        LIMIT 1
      '''),
      parameters: {'budget_section_id': budgetSectionId},
    );

    if (result.isEmpty) return 0;
    final value = result.first[0];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<Reservation> create({
    required Session session,
    required String reservationNumber,
    required String programId,
    required String budgetSectionId,
    required String fundingId,
    required String title,
    required String? description,
    required String? beneficiary,
    required String? executionNote,
    required String? requesterDepartment,
    required String? contactPhone,
    required double reservedAmount,
    required String reservationDate,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO reservations (
          id,
          reservation_number,
          program_id,
          budget_section_id,
          funding_id,
          title,
          description,
          beneficiary,
          execution_note,
          requester_department,
          contact_phone,
          reserved_amount,
          workflow_status,
          reservation_date,
          created_by
        ) VALUES (
          @id,
          @reservation_number,
          @program_id::uuid,
          @budget_section_id::uuid,
          @funding_id::uuid,
          @title,
          @description,
          @beneficiary,
          @execution_note,
          @requester_department,
          @contact_phone,
          @reserved_amount,
          'draft',
          @reservation_date::date,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'reservation_number': reservationNumber,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'title': title,
        'description': description,
        'beneficiary': beneficiary,
        'execution_note': executionNote,
        'requester_department': requesterDepartment,
        'contact_phone': contactPhone,
        'reserved_amount': reservedAmount,
        'reservation_date': reservationDate,
        'created_by': createdBy,
      },
    );

    final reservation = await findById(session, id);
    if (reservation == null) {
      throw const AppException(
        message: 'Failed to load created reservation.',
        statusCode: 500,
        code: 'RESERVATION_CREATE_FAILED',
      );
    }

    return reservation;
  }

  Future<Reservation> updateDraft({
    required Session session,
    required String id,
    required String reservationNumber,
    required String programId,
    required String budgetSectionId,
    required String fundingId,
    required String title,
    required String? description,
    required String? beneficiary,
    required String? executionNote,
    required String? requesterDepartment,
    required String? contactPhone,
    required double reservedAmount,
    required String reservationDate,
    required String updatedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE reservations
        SET
          reservation_number = @reservation_number,
          program_id = @program_id::uuid,
          budget_section_id = @budget_section_id::uuid,
          funding_id = @funding_id::uuid,
          title = @title,
          description = @description,
          beneficiary = @beneficiary,
          execution_note = @execution_note,
          requester_department = @requester_department,
          contact_phone = @contact_phone,
          reserved_amount = @reserved_amount,
          reservation_date = @reservation_date::date,
          updated_by = @updated_by::uuid
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {
        'id': id,
        'reservation_number': reservationNumber,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'title': title,
        'description': description,
        'beneficiary': beneficiary,
        'execution_note': executionNote,
        'requester_department': requesterDepartment,
        'contact_phone': contactPhone,
        'reserved_amount': reservedAmount,
        'reservation_date': reservationDate,
        'updated_by': updatedBy,
      },
    );

    final reservation = await findById(session, id);
    if (reservation == null) {
      throw const AppException(
        message: 'Reservation not found after update.',
        statusCode: 404,
        code: 'RESERVATION_NOT_FOUND',
      );
    }

    return reservation;
  }

  Future<Reservation> changeStatus({
    required Session session,
    required String id,
    required String status,
    String? approvedAt,
    String? cancelledAt,
    String? closedAt,
    String? updatedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE reservations
        SET
          workflow_status = @status::reservation_status,
          approved_at = COALESCE(@approved_at::timestamptz, approved_at),
          cancelled_at = COALESCE(@cancelled_at::timestamptz, cancelled_at),
          closed_at = COALESCE(@closed_at::timestamptz, closed_at),
          updated_by = CASE
            WHEN @updated_by = '' THEN updated_by
            ELSE @updated_by::uuid
          END
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {
        'id': id,
        'status': status,
        'approved_at': approvedAt,
        'cancelled_at': cancelledAt,
        'closed_at': closedAt,
        'updated_by': updatedBy ?? '',
      },
    );

    final reservation = await findById(session, id);
    if (reservation == null) {
      throw const AppException(
        message: 'Reservation not found after status change.',
        statusCode: 404,
        code: 'RESERVATION_NOT_FOUND',
      );
    }

    return reservation;
  }

  Future<bool> hasActiveExpenses(Session session, String reservationId) async {
    final result = await session.execute(
      Sql.named('''
        SELECT EXISTS (
          SELECT 1
          FROM expenses
          WHERE reservation_id = @reservation_id::uuid
            AND deleted_at IS NULL
            AND expense_status::text <> 'cancelled'
          LIMIT 1
        )
      '''),
      parameters: {'reservation_id': reservationId},
    );

    return result.first[0] == true;
  }

  Future<void> softDelete({
    required Session session,
    required String id,
    required String deletedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE reservations
        SET deleted_at = NOW(),
            deleted_by = @deleted_by::uuid,
            updated_by = @deleted_by::uuid
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'deleted_by': deletedBy},
    );
  }

  Future<void> createLedgerTransaction({
    required Session session,
    required String reservationId,
    required String fundingId,
    required String programId,
    required String budgetSectionId,
    required String createdBy,
    required double amount,
    required String transactionType,
    required String description,
  }) async {
    await session.execute(
      Sql.named('''
        INSERT INTO financial_transactions (
          id,
          transaction_number,
          transaction_type,
          amount,
          description,
          reference_table,
          reference_id,
          program_id,
          budget_section_id,
          section_id,
          fiscal_year_id,
          budget_type_id,
          funding_id,
          reservation_id,
          created_by
        ) VALUES (
          @id,
          @transaction_number,
          @transaction_type::transaction_type,
          @amount,
          @description,
          'reservations',
          @reference_id::uuid,
          @program_id::uuid,
          @budget_section_id::uuid,
          @budget_section_id::uuid,
          (
            SELECT fiscal_year_id
            FROM budget_sections
            WHERE id = @budget_section_id::uuid
            LIMIT 1
          ),
          (
            SELECT budget_type_id
            FROM budget_sections
            WHERE id = @budget_section_id::uuid
            LIMIT 1
          ),
          @funding_id::uuid,
          @reservation_id::uuid,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            'RT-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': transactionType,
        'amount': amount,
        'description': description,
        'reference_id': reservationId,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'reservation_id': reservationId,
        'created_by': createdBy,
      },
    );
  }
}
