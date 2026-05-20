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
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        WHERE
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
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        WHERE f.id = @id::uuid
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
          f.notes,
          f.created_at
        FROM fundings f
        INNER JOIN programs p ON p.id = f.program_id
        INNER JOIN budget_sections bs ON bs.id = f.budget_section_id
        WHERE LOWER(f.funding_reference) = LOWER(@reference)
          AND (@ignore_id = '' OR f.id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {'reference': reference, 'ignore_id': ignoreId ?? ''},
    );

    if (result.isEmpty) return null;
    return Funding.fromRow(result.first.toColumnMap());
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
        message: 'Budget section not found.',
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
        message: 'Failed to load created funding.',
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
        message: 'Funding not found after update.',
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
          @funding_id::uuid,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': _uuid.v4(),
        'transaction_number':
            'FT-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
        'transaction_type': transactionType,
        'amount': amount,
        'description': description,
        'reference_id': fundingId,
        'program_id': programId,
        'budget_section_id': budgetSectionId,
        'funding_id': fundingId,
        'created_by': createdBy,
      },
    );
  }
}
