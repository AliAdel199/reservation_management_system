import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/monthly_funding.dart';
import '../models/paged_result.dart';

class MonthlyFundingsRepository {
  const MonthlyFundingsRepository();

  static const _uuid = Uuid();
  static const _monthlyFundingLedgerCte = '''
    WITH monthly_ledger AS (
      SELECT
        COALESCE(ft.fiscal_year_id, bs.fiscal_year_id) AS fiscal_year_id,
        COALESCE(ft.program_id, bs.program_id) AS program_id,
        COALESCE(SUM(
          CASE
            WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
            WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
            ELSE 0
          END
        ), 0) AS reserved_amount,
        COALESCE(SUM(
          CASE
            WHEN ft.transaction_type::text = 'expense_disbursement' THEN ft.amount
            WHEN ft.transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -ft.amount
            ELSE 0
          END
        ), 0) AS spent_amount
      FROM financial_transactions ft
      LEFT JOIN budget_sections bs
        ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
      WHERE ft.transaction_type::text IN (
        'reservation_hold',
        'reservation_release',
        'reservation_cancel',
        'expense_disbursement',
        'expense_reversal',
        'expense_cancel'
      )
      GROUP BY
        COALESCE(ft.fiscal_year_id, bs.fiscal_year_id),
        COALESCE(ft.program_id, bs.program_id)
    )
  ''';

  Future<PagedResult<MonthlyFunding>> list(
    Session session, {
    required String search,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String? programId,
    required String? sectionId,
    required int? month,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;
    final filterParams = {
      'search': normalizedSearch,
      'pattern': '%$normalizedSearch%',
      'fiscal_year_id': fiscalYearId ?? '',
      'budget_type_id': budgetTypeId ?? '',
      'program_id': programId ?? '',
      'section_id': sectionId ?? '',
      'month': month ?? 0,
    };
    final listParams = {...filterParams, 'limit': pageSize, 'offset': offset};

    final where = '''
      mf.deleted_at IS NULL
      AND (@fiscal_year_id = '' OR mf.fiscal_year_id = @fiscal_year_id::uuid)
      AND (@budget_type_id = '' OR mf.budget_type_id = @budget_type_id::uuid)
      AND (@program_id = '' OR mf.program_id = @program_id::uuid)
      AND (@section_id = '' OR mf.section_id = @section_id::uuid)
      AND (@month = 0 OR mf.month = @month)
      AND (
        @search = ''
        OR p.name ILIKE @pattern
        OR COALESCE(bs.name, '') ILIKE @pattern
        OR mf.notes ILIKE @pattern
      )
    ''';

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM monthly_fundings mf
        INNER JOIN fiscal_years fy ON fy.id = mf.fiscal_year_id
        INNER JOIN budget_types bt ON bt.id = mf.budget_type_id
        INNER JOIN programs p ON p.id = mf.program_id
        LEFT JOIN budget_sections bs ON bs.id = mf.section_id
        WHERE $where
      '''),
      parameters: filterParams,
    );

    final itemsResult = await session.execute(
      Sql.named('''
        $_monthlyFundingLedgerCte
        SELECT
          mf.id,
          mf.fiscal_year_id,
          fy.year AS fiscal_year,
          mf.budget_type_id,
          bt.name AS budget_type_name,
          mf.program_id,
          p.name AS program_name,
          mf.section_id,
          COALESCE(bs.name, 'تمويل عام على مستوى البرنامج') AS section_name,
          mf.month,
          mf.amount,
          COALESCE(ml.reserved_amount, 0) AS reserved_amount,
          COALESCE(ml.spent_amount, 0) AS spent_amount,
          mf.amount - COALESCE(ml.reserved_amount, 0) AS remaining_amount,
          mf.funding_date,
          mf.notes,
          mf.created_at
        FROM monthly_fundings mf
        INNER JOIN fiscal_years fy ON fy.id = mf.fiscal_year_id
        INNER JOIN budget_types bt ON bt.id = mf.budget_type_id
        INNER JOIN programs p ON p.id = mf.program_id
        LEFT JOIN budget_sections bs ON bs.id = mf.section_id
        LEFT JOIN monthly_ledger ml
          ON ml.fiscal_year_id = mf.fiscal_year_id
          AND ml.program_id = mf.program_id
        WHERE $where
        ORDER BY mf.funding_date DESC, mf.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: listParams,
    );

    return PagedResult<MonthlyFunding>(
      items: itemsResult
          .map((row) => MonthlyFunding.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<MonthlyFunding?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        $_monthlyFundingLedgerCte
        SELECT
          mf.id,
          mf.fiscal_year_id,
          fy.year AS fiscal_year,
          mf.budget_type_id,
          bt.name AS budget_type_name,
          mf.program_id,
          p.name AS program_name,
          mf.section_id,
          COALESCE(bs.name, 'تمويل عام على مستوى البرنامج') AS section_name,
          mf.month,
          mf.amount,
          COALESCE(ml.reserved_amount, 0) AS reserved_amount,
          COALESCE(ml.spent_amount, 0) AS spent_amount,
          mf.amount - COALESCE(ml.reserved_amount, 0) AS remaining_amount,
          mf.funding_date,
          mf.notes,
          mf.created_at
        FROM monthly_fundings mf
        INNER JOIN fiscal_years fy ON fy.id = mf.fiscal_year_id
        INNER JOIN budget_types bt ON bt.id = mf.budget_type_id
        INNER JOIN programs p ON p.id = mf.program_id
        LEFT JOIN budget_sections bs ON bs.id = mf.section_id
        LEFT JOIN monthly_ledger ml
          ON ml.fiscal_year_id = mf.fiscal_year_id
          AND ml.program_id = mf.program_id
        WHERE mf.id = @id::uuid
          AND mf.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return MonthlyFunding.fromRow(result.first.toColumnMap());
  }

  Future<String> resolveBudgetTypeIdForProgram(
    Session session,
    String programId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        SELECT DISTINCT bs.budget_type_id
        FROM budget_sections bs
        WHERE bs.program_id = @program_id::uuid
          AND bs.deleted_at IS NULL
          AND bs.budget_type_id IS NOT NULL
      '''),
      parameters: {'program_id': programId},
    );

    if (result.isEmpty) {
      return _ensureBudgetTypeForProgram(session, programId);
    }

    if (result.length > 1) {
      throw const AppException(
        message:
            'هذا البرنامج مرتبط بأكثر من نوع ميزانية. وحّد نوع الميزانية في أبواب البرنامج ثم أعد المحاولة.',
        statusCode: 422,
        code: 'PROGRAM_HAS_MULTIPLE_BUDGET_TYPES',
      );
    }

    return result.first[0].toString();
  }

  Future<String> _ensureBudgetTypeForProgram(
    Session session,
    String programId,
  ) async {
    final programResult = await session.execute(
      Sql.named('''
        SELECT code, name
        FROM programs
        WHERE id = @program_id::uuid
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'program_id': programId},
    );

    if (programResult.isEmpty) {
      throw const AppException(
        message: 'Parent program not found.',
        statusCode: 404,
        code: 'PROGRAM_NOT_FOUND',
      );
    }

    final program = programResult.first.toColumnMap();
    final programCode = program['code'].toString();
    final programName = program['name'].toString();

    final existingByName = await session.execute(
      Sql.named('''
        SELECT id
        FROM budget_types
        WHERE LOWER(name) = LOWER(@name)
        LIMIT 1
      '''),
      parameters: {'name': programName},
    );
    if (existingByName.isNotEmpty) return existingByName.first[0].toString();

    final existingByCode = await session.execute(
      Sql.named('''
        SELECT id
        FROM budget_types
        WHERE LOWER(code) = LOWER(@code)
        LIMIT 1
      '''),
      parameters: {'code': programCode},
    );
    if (existingByCode.isNotEmpty) return existingByCode.first[0].toString();

    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO budget_types (id, code, name, description, is_active)
        VALUES (
          @id,
          @code,
          @name,
          'تم إنشاؤه تلقائياً لأن البرامج وأنواع الميزانيات مدمجة في الواجهة.',
          TRUE
        )
      '''),
      parameters: {'id': id, 'code': programCode, 'name': programName},
    );
    return id;
  }

  Future<MonthlyFunding> create({
    required Session session,
    required String fiscalYearId,
    required String budgetTypeId,
    required String programId,
    required String? sectionId,
    required int month,
    required double amount,
    required String fundingDate,
    required String? notes,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO monthly_fundings (
          id,
          fiscal_year_id,
          budget_type_id,
          program_id,
          section_id,
          month,
          amount,
          funding_date,
          notes,
          created_by
        ) VALUES (
          @id,
          @fiscal_year_id::uuid,
          @budget_type_id::uuid,
          @program_id::uuid,
          @section_id::uuid,
          @month,
          @amount,
          @funding_date::date,
          @notes,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'fiscal_year_id': fiscalYearId,
        'budget_type_id': budgetTypeId,
        'program_id': programId,
        'section_id': sectionId,
        'month': month,
        'amount': amount,
        'funding_date': fundingDate,
        'notes': notes,
        'created_by': createdBy,
      },
    );

    final monthlyFunding = await findById(session, id);
    if (monthlyFunding == null) {
      throw const AppException(
        message: 'Failed to load created monthly funding.',
        statusCode: 500,
        code: 'MONTHLY_FUNDING_CREATE_FAILED',
      );
    }
    return monthlyFunding;
  }

  Future<MonthlyFunding> update({
    required Session session,
    required String id,
    required String fiscalYearId,
    required String budgetTypeId,
    required String programId,
    required String? sectionId,
    required int month,
    required double amount,
    required String fundingDate,
    required String? notes,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE monthly_fundings
        SET fiscal_year_id = @fiscal_year_id::uuid,
            budget_type_id = @budget_type_id::uuid,
            program_id = @program_id::uuid,
            section_id = @section_id::uuid,
            month = @month,
            amount = @amount,
            funding_date = @funding_date::date,
            notes = @notes
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {
        'id': id,
        'fiscal_year_id': fiscalYearId,
        'budget_type_id': budgetTypeId,
        'program_id': programId,
        'section_id': sectionId,
        'month': month,
        'amount': amount,
        'funding_date': fundingDate,
        'notes': notes,
      },
    );

    final monthlyFunding = await findById(session, id);
    if (monthlyFunding == null) {
      throw const AppException(
        message: 'Monthly funding not found after update.',
        statusCode: 404,
        code: 'MONTHLY_FUNDING_NOT_FOUND',
      );
    }
    return monthlyFunding;
  }

  Future<void> softDelete({
    required Session session,
    required String id,
    required String deletedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE monthly_fundings
        SET deleted_at = NOW(),
            deleted_by = @deleted_by::uuid
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'deleted_by': deletedBy},
    );
  }

  Future<void> createLedgerTransaction({
    required Session session,
    required MonthlyFunding monthlyFunding,
    required String createdBy,
    required String transactionType,
    required String direction,
    required double amount,
    required String description,
  }) async {
    await session.execute(
      Sql.named('''
        INSERT INTO financial_transactions (
          id,
          transaction_number,
          transaction_type,
          amount,
          direction,
          reference_table,
          reference_type,
          reference_id,
          fiscal_year_id,
          budget_type_id,
          program_id,
          budget_section_id,
          section_id,
          created_by,
          description
        ) VALUES (
          @id,
          @transaction_number,
          @transaction_type::transaction_type,
          @amount,
          @direction::transaction_direction,
          'monthly_fundings',
          'monthly_fundings',
          @reference_id::uuid,
          @fiscal_year_id::uuid,
          @budget_type_id::uuid,
          @program_id::uuid,
          @section_id::uuid,
          @section_id::uuid,
          @created_by::uuid,
          @description
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            'MF-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': transactionType,
        'amount': amount,
        'direction': direction,
        'reference_id': monthlyFunding.id,
        'fiscal_year_id': monthlyFunding.fiscalYearId,
        'budget_type_id': monthlyFunding.budgetTypeId,
        'program_id': monthlyFunding.programId,
        'section_id': monthlyFunding.sectionId,
        'created_by': createdBy,
        'description': description,
      },
    );
  }
}
