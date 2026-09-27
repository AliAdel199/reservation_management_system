import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/funding.dart';
import '../models/paged_result.dart';

class FundingsRepository {
  const FundingsRepository();

  static const _uuid = Uuid();

  Future<PagedResult<Funding>> list(
    Session session, {
    required String search,
    required String? programId,
    required String? budgetSectionId,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        WHERE
          f.deleted_at IS NULL
          AND
          (@program_id = '' OR f.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR f.budget_section_id = @budget_section_id::uuid)
          AND (
            @search = ''
            OR LOWER(f.funding_reference) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
            OR LOWER(bs.name) LIKE LOWER(@pattern)
          )
      '''),
      parameters: {
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
      },
    );

    final itemsResult = await session.execute(
      Sql.named('''
        WITH section_ledger AS (
          SELECT
            COALESCE(section_id, budget_section_id) AS budget_section_id,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'reservation_hold' THEN amount
              WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
              ELSE 0
            END), 0) AS reserved_amount,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'expense_disbursement' THEN amount
              WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
              ELSE 0
            END), 0) AS spent_amount
          FROM financial_transactions
          GROUP BY COALESCE(section_id, budget_section_id)
        )
        SELECT
          f.id,
          f.program_id,
          p.code AS program_code,
          p.name AS program_name,
          f.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          f.funding_reference,
          f.fiscal_year,
          f.allocated_amount,
          bs.allocated_amount AS current_allocated_amount,
          COALESCE(sl.reserved_amount, 0) AS reserved_amount,
          COALESCE(sl.spent_amount, 0) AS spent_amount,
          bs.allocated_amount
            - COALESCE(sl.reserved_amount, 0)
            - COALESCE(sl.spent_amount, 0) AS available_amount,
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        LEFT JOIN section_ledger sl ON sl.budget_section_id = bs.id
        WHERE
          f.deleted_at IS NULL
          AND
          (@program_id = '' OR f.program_id = @program_id::uuid)
          AND (@budget_section_id = '' OR f.budget_section_id = @budget_section_id::uuid)
          AND (
            @search = ''
            OR LOWER(f.funding_reference) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
            OR LOWER(bs.name) LIKE LOWER(@pattern)
          )
        ORDER BY f.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    return PagedResult<Funding>(
      items: itemsResult
          .map((row) => Funding.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Funding?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        WITH section_ledger AS (
          SELECT
            COALESCE(section_id, budget_section_id) AS budget_section_id,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'reservation_hold' THEN amount
              WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
              ELSE 0
            END), 0) AS reserved_amount,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'expense_disbursement' THEN amount
              WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
              ELSE 0
            END), 0) AS spent_amount
          FROM financial_transactions
          GROUP BY COALESCE(section_id, budget_section_id)
        )
        SELECT
          f.id,
          f.program_id,
          p.code AS program_code,
          p.name AS program_name,
          f.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          f.funding_reference,
          f.fiscal_year,
          f.allocated_amount,
          bs.allocated_amount AS current_allocated_amount,
          COALESCE(sl.reserved_amount, 0) AS reserved_amount,
          COALESCE(sl.spent_amount, 0) AS spent_amount,
          bs.allocated_amount
            - COALESCE(sl.reserved_amount, 0)
            - COALESCE(sl.spent_amount, 0) AS available_amount,
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        LEFT JOIN section_ledger sl ON sl.budget_section_id = bs.id
        WHERE f.id = @id::uuid
          AND f.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;
    return Funding.fromRow(result.first.toColumnMap());
  }

  Future<Funding?> findByReference(
    Session session,
    String reference, {
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        WITH section_ledger AS (
          SELECT
            COALESCE(section_id, budget_section_id) AS budget_section_id,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'reservation_hold' THEN amount
              WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
              ELSE 0
            END), 0) AS reserved_amount,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'expense_disbursement' THEN amount
              WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
              ELSE 0
            END), 0) AS spent_amount
          FROM financial_transactions
          GROUP BY COALESCE(section_id, budget_section_id)
        )
        SELECT
          f.id,
          f.program_id,
          p.code AS program_code,
          p.name AS program_name,
          f.budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          f.funding_reference,
          f.fiscal_year,
          f.allocated_amount,
          bs.allocated_amount AS current_allocated_amount,
          COALESCE(sl.reserved_amount, 0) AS reserved_amount,
          COALESCE(sl.spent_amount, 0) AS spent_amount,
          bs.allocated_amount
            - COALESCE(sl.reserved_amount, 0)
            - COALESCE(sl.spent_amount, 0) AS available_amount,
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        LEFT JOIN section_ledger sl ON sl.budget_section_id = bs.id
        WHERE LOWER(f.funding_reference) = LOWER(@reference)
          AND f.deleted_at IS NULL
          AND (@ignore_id = '' OR f.id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {'reference': reference, 'ignore_id': ignoreId ?? ''},
    );

    if (result.isEmpty) return null;
    return Funding.fromRow(result.first.toColumnMap());
  }

  Future<void> transferAllocation({
    required Session session,
    required String fromSectionId,
    required String toSectionId,
    required double amount,
    required String reference,
    required String? notes,
    required String createdBy,
  }) async {
    final sectionsResult = await session.execute(
      Sql.named('''
        WITH section_ledger AS (
          SELECT
            COALESCE(section_id, budget_section_id) AS budget_section_id,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'reservation_hold' THEN amount
              WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
              ELSE 0
            END), 0) AS reserved_amount,
            COALESCE(SUM(CASE
              WHEN transaction_type::text = 'expense_disbursement' THEN amount
              WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
              ELSE 0
            END), 0) AS spent_amount
          FROM financial_transactions
          GROUP BY COALESCE(section_id, budget_section_id)
        )
        SELECT
          bs.id,
          bs.program_id,
          bs.fiscal_year_id,
          bs.budget_type_id,
          bs.code,
          bs.name,
          bs.allocated_amount,
          COALESCE(sl.reserved_amount, 0) AS reserved_amount,
          COALESCE(sl.spent_amount, 0) AS spent_amount,
          bs.allocated_amount
            - COALESCE(sl.reserved_amount, 0)
            - COALESCE(sl.spent_amount, 0) AS available_amount,
          bs.is_postable,
          bs.is_active
        FROM budget_sections bs
        LEFT JOIN section_ledger sl ON sl.budget_section_id = bs.id
        WHERE (
            bs.id = @from_section_id::uuid
            OR bs.id = @to_section_id::uuid
          )
          AND bs.deleted_at IS NULL
        FOR UPDATE OF bs
      '''),
      parameters: {
        'from_section_id': fromSectionId,
        'to_section_id': toSectionId,
      },
    );

    final sections = <String, Map<String, dynamic>>{};
    for (final row in sectionsResult) {
      final data = row.toColumnMap();
      sections[data['id'].toString()] = data;
    }
    final from = sections[fromSectionId];
    final to = sections[toSectionId];

    if (from == null || to == null) {
      throw const AppException(
        message: 'باب المصدر أو الهدف غير موجود.',
        statusCode: 404,
        code: 'TRANSFER_SECTION_NOT_FOUND',
      );
    }

    if (fromSectionId == toSectionId) {
      throw const AppException(
        message: 'لا يمكن المناقلة لنفس الباب.',
        statusCode: 422,
        code: 'TRANSFER_SAME_SECTION',
      );
    }

    final fromPostable = from['is_postable'] == true;
    final toPostable = to['is_postable'] == true;
    final fromActive = from['is_active'] == true;
    final toActive = to['is_active'] == true;
    if (!fromPostable || !toPostable || !fromActive || !toActive) {
      throw const AppException(
        message: 'المناقلة تقبل الأبواب النهائية الفعالة فقط.',
        statusCode: 422,
        code: 'TRANSFER_REQUIRES_POSTABLE_SECTIONS',
      );
    }

    final fromAvailableAmount = _parseDouble(from['available_amount']);
    if (amount <= 0) {
      throw const AppException(
        message: 'مبلغ المناقلة يجب أن يكون أكبر من صفر.',
        statusCode: 422,
        code: 'INVALID_TRANSFER_AMOUNT',
      );
    }

    final sameFiscalYear =
        from['fiscal_year_id']?.toString() == to['fiscal_year_id']?.toString();
    final sameBudgetType =
        from['budget_type_id']?.toString() == to['budget_type_id']?.toString();
    if (!sameFiscalYear || !sameBudgetType) {
      throw const AppException(
        message: 'المناقلة يجب أن تكون ضمن نفس السنة المالية ونوع الميزانية.',
        statusCode: 422,
        code: 'TRANSFER_SCOPE_MISMATCH',
      );
    }

    if (fromAvailableAmount < amount) {
      throw AppException(
        message:
            'مبلغ المناقلة أكبر من المتبقي المتاح في باب المصدر. المتاح للمناقلة: ${fromAvailableAmount.toStringAsFixed(0)}.',
        statusCode: 422,
        code: 'INSUFFICIENT_SOURCE_ALLOCATION',
      );
    }

    await session.execute(
      Sql.named('''
        UPDATE budget_sections
        SET allocated_amount = allocated_amount - @amount
        WHERE id = @from_section_id::uuid
      '''),
      parameters: {'from_section_id': fromSectionId, 'amount': amount},
    );

    await session.execute(
      Sql.named('''
        UPDATE budget_sections
        SET allocated_amount = allocated_amount + @amount
        WHERE id = @to_section_id::uuid
      '''),
      parameters: {'to_section_id': toSectionId, 'amount': amount},
    );

    final baseDescription =
        'مناقلة تخصيص $reference من ${from['code']} - ${from['name']} إلى ${to['code']} - ${to['name']}';
    await createAllocationMovement(
      session: session,
      programId: from['program_id'].toString(),
      budgetSectionId: fromSectionId,
      fiscalYearId: from['fiscal_year_id']?.toString(),
      budgetTypeId: from['budget_type_id']?.toString(),
      createdBy: createdBy,
      amount: amount,
      transactionType: 'adjustment_decrease',
      transactionNumberPrefix: 'ALLOC-TR-OUT',
      description: notes == null || notes.isEmpty
          ? baseDescription
          : '$baseDescription - $notes',
    );

    await createAllocationMovement(
      session: session,
      programId: to['program_id'].toString(),
      budgetSectionId: toSectionId,
      fiscalYearId: to['fiscal_year_id']?.toString(),
      budgetTypeId: to['budget_type_id']?.toString(),
      createdBy: createdBy,
      amount: amount,
      transactionType: 'adjustment_increase',
      transactionNumberPrefix: 'ALLOC-TR-IN',
      description: notes == null || notes.isEmpty
          ? baseDescription
          : '$baseDescription - $notes',
    );
  }

  Future<void> applyFundingAllocationChange({
    required Session session,
    required String? oldBudgetSectionId,
    required double oldAmount,
    required String newBudgetSectionId,
    required double newAmount,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id, allocated_amount, is_postable, is_active
        FROM budget_sections
        WHERE (
            id = @new_budget_section_id::uuid
            OR (
              @old_budget_section_id <> ''
              AND id = @old_budget_section_id::uuid
            )
          )
          AND deleted_at IS NULL
        FOR UPDATE
      '''),
      parameters: {
        'new_budget_section_id': newBudgetSectionId,
        'old_budget_section_id': oldBudgetSectionId ?? '',
      },
    );

    final sections = <String, Map<String, dynamic>>{};
    for (final row in result) {
      final data = row.toColumnMap();
      sections[data['id'].toString()] = data;
    }

    final newSection = sections[newBudgetSectionId];
    if (newSection == null) {
      throw const AppException(
        message: 'الباب غير موجود.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    if (newSection['is_postable'] != true || newSection['is_active'] != true) {
      throw const AppException(
        message: 'التخصيص يقبل الأبواب النهائية الفعالة فقط.',
        statusCode: 422,
        code: 'FUNDING_REQUIRES_POSTABLE_SECTION',
      );
    }

    if (oldBudgetSectionId == null || oldBudgetSectionId.isEmpty) {
      await _adjustSectionAllocation(
        session: session,
        budgetSectionId: newBudgetSectionId,
        delta: newAmount,
      );
      return;
    }

    final oldSection = sections[oldBudgetSectionId];
    if (oldSection == null) {
      throw const AppException(
        message: 'الباب الأصلي غير موجود.',
        statusCode: 404,
        code: 'ORIGINAL_BUDGET_SECTION_NOT_FOUND',
      );
    }

    if (oldBudgetSectionId == newBudgetSectionId) {
      final delta = newAmount - oldAmount;
      final currentAmount = _parseDouble(oldSection['allocated_amount']);
      if (currentAmount + delta < 0) {
        throw const AppException(
          message: 'لا يمكن جعل التخصيص الحالي للباب أقل من صفر.',
          statusCode: 422,
          code: 'NEGATIVE_SECTION_ALLOCATION',
        );
      }
      if (delta != 0) {
        await _adjustSectionAllocation(
          session: session,
          budgetSectionId: newBudgetSectionId,
          delta: delta,
        );
      }
      return;
    }

    final oldCurrentAmount = _parseDouble(oldSection['allocated_amount']);
    if (oldCurrentAmount - oldAmount < 0) {
      throw const AppException(
        message:
            'لا يمكن نقل التخصيص لأن رصيد الباب القديم لا يكفي بعد المناقلات.',
        statusCode: 422,
        code: 'INSUFFICIENT_OLD_SECTION_ALLOCATION',
      );
    }

    await _adjustSectionAllocation(
      session: session,
      budgetSectionId: oldBudgetSectionId,
      delta: -oldAmount,
    );
    await _adjustSectionAllocation(
      session: session,
      budgetSectionId: newBudgetSectionId,
      delta: newAmount,
    );
  }

  Future<List<Map<String, dynamic>>> allocationMovements(
    Session session, {
    required String? programId,
    required String? budgetSectionId,
    required String? fromDate,
    required String? toDate,
    required int limit,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          ft.id,
          ft.transaction_number,
          ft.transaction_type::text AS transaction_type,
          ft.amount,
          ft.transaction_date,
          ft.description,
          p.id AS program_id,
          p.name AS program_name,
          bs.id AS budget_section_id,
          bs.code AS budget_section_code,
          bs.name AS budget_section_name,
          u.full_name AS created_by_name
        FROM financial_transactions ft
        LEFT JOIN programs p ON p.id = ft.program_id
        LEFT JOIN budget_sections bs ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
        LEFT JOIN users u ON u.id = ft.created_by
        WHERE ft.transaction_type::text IN (
          'allocation',
          'allocation_reversal',
          'adjustment_increase',
          'adjustment_decrease'
        )
          AND (@program_id = '' OR ft.program_id = @program_id::uuid)
          AND (
            @budget_section_id = ''
            OR COALESCE(ft.section_id, ft.budget_section_id) = @budget_section_id::uuid
          )
          AND (@from_date = '' OR ft.transaction_date::date >= @from_date::date)
          AND (@to_date = '' OR ft.transaction_date::date <= @to_date::date)
        ORDER BY ft.transaction_date DESC
        LIMIT @limit
      '''),
      parameters: {
        'program_id': programId ?? '',
        'budget_section_id': budgetSectionId ?? '',
        'from_date': fromDate ?? '',
        'to_date': toDate ?? '',
        'limit': limit,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return {
        'id': data['id']?.toString(),
        'transaction_number': data['transaction_number']?.toString(),
        'transaction_type': data['transaction_type']?.toString(),
        'amount': _parseDouble(data['amount']),
        'transaction_date': data['transaction_date']?.toString(),
        'description': data['description']?.toString(),
        'program_id': data['program_id']?.toString(),
        'program_name': data['program_name']?.toString(),
        'budget_section_id': data['budget_section_id']?.toString(),
        'budget_section_code': data['budget_section_code']?.toString(),
        'budget_section_name': data['budget_section_name']?.toString(),
        'created_by_name': data['created_by_name']?.toString(),
      };
    }).toList();
  }

  Future<Funding> ensureAnnualSectionFunding({
    required Session session,
    required String budgetSectionId,
    required String createdBy,
  }) async {
    final sectionResult = await session.execute(
      Sql.named('''
        SELECT
          bs.id,
          bs.program_id,
          bs.code,
          bs.name,
          bs.allocated_amount,
          fy.year AS fiscal_year
        FROM budget_sections bs
        LEFT JOIN fiscal_years fy ON fy.id = bs.fiscal_year_id
        WHERE bs.id = @budget_section_id::uuid
          AND bs.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'budget_section_id': budgetSectionId},
    );

    if (sectionResult.isEmpty) {
      throw const AppException(
        message: 'الباب غير موجود.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    final section = sectionResult.first.toColumnMap();
    final reference = 'ANNUAL-SECTION-$budgetSectionId';
    final existing = await findByReference(session, reference);
    if (existing != null) {
      return existing;
    }

    // تعليق عربي: هذا سجل توافق داخلي فقط حتى تبقى الحجوزات القديمة مرتبطة بجدول fundings،
    // أما مصدر التخصيص الحقيقي فهو allocated_amount في جدول الأبواب.
    return create(
      session: session,
      programId: section['program_id'].toString(),
      budgetSectionId: budgetSectionId,
      fundingReference: reference,
      fiscalYear:
          int.tryParse(section['fiscal_year']?.toString() ?? '') ??
          DateTime.now().year,
      allocatedAmount: section['allocated_amount'] is num
          ? (section['allocated_amount'] as num).toDouble()
          : double.tryParse(section['allocated_amount']?.toString() ?? '0') ??
                0,
      notes:
          'سجل داخلي تلقائي لربط الحجوزات بالتخصيص السنوي للباب ${section['code']} - ${section['name']}.',
      createdBy: createdBy,
    );
  }

  Future<Funding> create({
    required Session session,
    required String programId,
    required String budgetSectionId,
    required String fundingReference,
    required int fiscalYear,
    required double allocatedAmount,
    required String? notes,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO fundings (
          id,
          program_id,
          budget_section_id,
          funding_reference,
          fiscal_year,
          allocated_amount,
          notes,
          created_by
        ) VALUES (
          @id,
          @program_id::uuid,
          @budget_section_id::uuid,
          @funding_reference,
          @fiscal_year,
          @allocated_amount,
          @notes,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_reference': fundingReference,
        'fiscal_year': fiscalYear,
        'allocated_amount': allocatedAmount,
        'notes': notes,
        'created_by': createdBy,
      },
    );

    final funding = await findById(session, id);
    if (funding == null) {
      throw const AppException(
        message: 'تعذر تحميل التخصيص بعد إنشائه.',
        statusCode: 500,
        code: 'FUNDING_CREATE_FAILED',
      );
    }

    return funding;
  }

  Future<Funding> update({
    required Session session,
    required String id,
    required String programId,
    required String budgetSectionId,
    required String fundingReference,
    required int fiscalYear,
    required double allocatedAmount,
    required String? notes,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE fundings
        SET
          program_id = @program_id::uuid,
          budget_section_id = @budget_section_id::uuid,
          funding_reference = @funding_reference,
          fiscal_year = @fiscal_year,
          allocated_amount = @allocated_amount,
          notes = @notes
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_reference': fundingReference,
        'fiscal_year': fiscalYear,
        'allocated_amount': allocatedAmount,
        'notes': notes,
      },
    );

    final funding = await findById(session, id);
    if (funding == null) {
      throw const AppException(
        message: 'تعذر تحميل التخصيص بعد التعديل.',
        statusCode: 404,
        code: 'FUNDING_NOT_FOUND',
      );
    }

    return funding;
  }

  Future<void> createLedgerTransaction({
    required Session session,
    required String fundingId,
    required String programId,
    required String budgetSectionId,
    required String createdBy,
    required double amount,
    required String transactionType,
    required String description,
  }) async {
    await createAllocationMovement(
      session: session,
      programId: programId,
      budgetSectionId: budgetSectionId,
      fundingId: fundingId,
      createdBy: createdBy,
      amount: amount,
      transactionType: transactionType,
      transactionNumberPrefix: 'FT',
      description: description,
    );
  }

  Future<void> createAllocationMovement({
    required Session session,
    required String programId,
    required String budgetSectionId,
    required String createdBy,
    required double amount,
    required String transactionType,
    required String transactionNumberPrefix,
    required String description,
    String? fiscalYearId,
    String? budgetTypeId,
    String? fundingId,
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
          created_by
        ) VALUES (
          @id,
          @transaction_number,
          @transaction_type::transaction_type,
          @amount,
          @description,
          'fundings',
          @reference_id::uuid,
          @program_id::uuid,
          @budget_section_id::uuid,
          @budget_section_id::uuid,
          NULLIF(@fiscal_year_id, '')::uuid,
          NULLIF(@budget_type_id, '')::uuid,
          NULLIF(@funding_id, '')::uuid,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            '$transactionNumberPrefix-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': transactionType,
        'amount': amount,
        'description': description,
        'reference_id': fundingId ?? budgetSectionId,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'funding_id': fundingId ?? '',
        'created_by': createdBy,
      },
    );
  }

  Future<void> _adjustSectionAllocation({
    required Session session,
    required String budgetSectionId,
    required double delta,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE budget_sections
        SET allocated_amount = allocated_amount + @delta
        WHERE id = @budget_section_id::uuid
      '''),
      parameters: {'budget_section_id': budgetSectionId, 'delta': delta},
    );
  }

  double _parseDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '0') ?? 0;
}
