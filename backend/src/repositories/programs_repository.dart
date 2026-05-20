import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/paged_result.dart';
import '../models/program.dart';

class ProgramsRepository {
  const ProgramsRepository();

  static const _uuid = Uuid();

  Future<PagedResult<Program>> list(
    Session session, {
    required String search,
    required String? fiscalYearId,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final normalizedFiscalYearId = fiscalYearId?.trim() ?? '';
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        WITH effective_year AS (
          -- تعليق عربي: إذا لم يرسل المستخدم سنة مالية نستخدم السنة الفعالة تلقائياً.
          SELECT COALESCE(
            NULLIF(@fiscal_year_id, '')::uuid,
            (
              SELECT id
              FROM fiscal_years
              WHERE is_active = TRUE
              ORDER BY year DESC
              LIMIT 1
            )
          ) AS id
        )
        SELECT COUNT(*)
        FROM programs p
        CROSS JOIN effective_year ey
        WHERE
          p.deleted_at IS NULL
          AND (ey.id IS NULL OR p.fiscal_year_id = ey.id)
          AND (
            @search = ''
            OR LOWER(p.code) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
          )
      '''),
      parameters: {
        'search': normalizedSearch,
        'fiscal_year_id': normalizedFiscalYearId,
        'pattern': '%$normalizedSearch%',
      },
    );

    final itemsResult = await session.execute(
      Sql.named('''
        WITH effective_year AS (
          -- تعليق عربي: مجموع التخصيصات هنا يعتمد على التخصيص السنوي للأبواب.
          -- التمويل الشهري معلّق حالياً لحين تثبيت فكرته.
          SELECT COALESCE(
            NULLIF(@fiscal_year_id, '')::uuid,
            (
              SELECT id
              FROM fiscal_years
              WHERE is_active = TRUE
              ORDER BY year DESC
              LIMIT 1
            )
          ) AS id
        ),
        allocation_fallback AS (
          SELECT
            f.budget_section_id AS section_id,
            COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
          FROM fundings f
          WHERE f.deleted_at IS NULL
          GROUP BY f.budget_section_id
        ),
        program_allocations AS (
          SELECT
            bs.program_id,
            COALESCE(SUM(
              CASE
                WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
                ELSE COALESCE(af.total_allocation, 0)
              END
            ), 0) AS total_allocations
          FROM budget_sections bs
          CROSS JOIN effective_year ey
          LEFT JOIN allocation_fallback af ON af.section_id = bs.id
          WHERE bs.deleted_at IS NULL
            AND (ey.id IS NULL OR bs.fiscal_year_id = ey.id)
          GROUP BY bs.program_id
        )
        SELECT
          p.id,
          p.code,
          p.name,
          p.description,
          p.fiscal_year_id,
          fy.name AS fiscal_year_name,
          p.fiscal_year,
          p.is_active,
          p.created_at,
          COUNT(DISTINCT bs.id) AS budget_sections_count,
          COUNT(DISTINCT f.id) AS fundings_count,
          COALESCE(pa.total_allocations, 0) AS total_allocations
        FROM programs p
        CROSS JOIN effective_year ey
        LEFT JOIN fiscal_years fy ON fy.id = p.fiscal_year_id
        LEFT JOIN budget_sections bs ON bs.program_id = p.id
          AND bs.deleted_at IS NULL
        LEFT JOIN fundings f ON f.program_id = p.id
          AND f.deleted_at IS NULL
        LEFT JOIN program_allocations pa ON pa.program_id = p.id
        WHERE
          p.deleted_at IS NULL
          AND (ey.id IS NULL OR p.fiscal_year_id = ey.id)
          AND (
            @search = ''
            OR LOWER(p.code) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
          )
        GROUP BY p.id, fy.id, pa.total_allocations
        ORDER BY p.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'search': normalizedSearch,
        'fiscal_year_id': normalizedFiscalYearId,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    final items = itemsResult
        .map((row) => Program.fromRow(row.toColumnMap()))
        .toList();

    return PagedResult<Program>(
      items: items,
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<Program>> lookupActive(Session session) async {
    final result = await session.execute('''
      SELECT
        p.id,
        p.code,
        p.name,
        p.description,
        p.fiscal_year_id,
        fy.name AS fiscal_year_name,
        p.fiscal_year,
        p.is_active,
        0 AS budget_sections_count,
        0 AS fundings_count,
        COALESCE((
          SELECT SUM(
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE((
                SELECT SUM(f.allocated_amount)
                FROM fundings f
                WHERE f.budget_section_id = bs.id
                  AND f.deleted_at IS NULL
              ), 0)
            END
          )
          FROM budget_sections bs
          WHERE bs.program_id = p.id
            AND bs.deleted_at IS NULL
            AND (p.fiscal_year_id IS NULL OR bs.fiscal_year_id = p.fiscal_year_id)
        ), 0) AS total_allocations,
        p.created_at
      FROM programs p
      LEFT JOIN fiscal_years fy ON fy.id = p.fiscal_year_id
      WHERE p.is_active = TRUE
        AND p.deleted_at IS NULL
      ORDER BY p.fiscal_year DESC, p.name ASC
    ''');

    return result.map((row) => Program.fromRow(row.toColumnMap())).toList();
  }

  Future<Program?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          p.id,
          p.code,
          p.name,
          p.description,
          p.fiscal_year_id,
          fy.name AS fiscal_year_name,
          p.fiscal_year,
          p.is_active,
          p.created_at,
          COUNT(DISTINCT bs.id) AS budget_sections_count,
          COUNT(DISTINCT f.id) AS fundings_count,
          COALESCE((
            SELECT SUM(
              CASE
                WHEN COALESCE(bs2.allocated_amount, 0) > 0 THEN bs2.allocated_amount
                ELSE COALESCE((
                  SELECT SUM(f.allocated_amount)
                  FROM fundings f
                  WHERE f.budget_section_id = bs2.id
                    AND f.deleted_at IS NULL
                ), 0)
              END
            )
            FROM budget_sections bs2
            WHERE bs2.program_id = p.id
              AND bs2.deleted_at IS NULL
              AND (p.fiscal_year_id IS NULL OR bs2.fiscal_year_id = p.fiscal_year_id)
          ), 0) AS total_allocations
        FROM programs p
        LEFT JOIN fiscal_years fy ON fy.id = p.fiscal_year_id
        LEFT JOIN budget_sections bs ON bs.program_id = p.id
          AND bs.deleted_at IS NULL
        LEFT JOIN fundings f ON f.program_id = p.id
          AND f.deleted_at IS NULL
        WHERE p.id = @id
        GROUP BY p.id, fy.id
        LIMIT 1
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) {
      return null;
    }

    return Program.fromRow(result.first.toColumnMap());
  }

  Future<Program?> findByCode(
    Session session,
    String code, {
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          p.id,
          p.code,
          p.name,
          p.description,
          p.fiscal_year_id,
          fy.name AS fiscal_year_name,
          p.fiscal_year,
          p.is_active,
          p.created_at,
          0 AS budget_sections_count,
          0 AS fundings_count,
          COALESCE((
            SELECT SUM(
              CASE
                WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
                ELSE COALESCE((
                  SELECT SUM(f.allocated_amount)
                  FROM fundings f
                  WHERE f.budget_section_id = bs.id
                    AND f.deleted_at IS NULL
                ), 0)
              END
            )
            FROM budget_sections bs
            WHERE bs.program_id = p.id
              AND bs.deleted_at IS NULL
              AND (p.fiscal_year_id IS NULL OR bs.fiscal_year_id = p.fiscal_year_id)
          ), 0) AS total_allocations
        FROM programs p
        LEFT JOIN fiscal_years fy ON fy.id = p.fiscal_year_id
        WHERE LOWER(p.code) = LOWER(@code)
          AND (@ignore_id = '' OR p.id <> @ignore_id::uuid)
          AND p.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'code': code, 'ignore_id': ignoreId ?? ''},
    );

    if (result.isEmpty) {
      return null;
    }

    return Program.fromRow(result.first.toColumnMap());
  }

  Future<Program> create({
    required Session session,
    required String code,
    required String name,
    required String? description,
    required String? fiscalYearId,
    required int fiscalYear,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO programs (
          id,
          code,
          name,
          description,
          fiscal_year_id,
          fiscal_year,
          is_active,
          created_by
        ) VALUES (
          @id,
          @code,
          @name,
          @description,
          NULLIF(@fiscal_year_id, '')::uuid,
          @fiscal_year,
          TRUE,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'fiscal_year_id': fiscalYearId ?? '',
        'fiscal_year': fiscalYear,
        'created_by': createdBy,
      },
    );

    final program = await findById(session, id);
    if (program == null) {
      throw const AppException(
        message: 'Failed to load created program.',
        statusCode: 500,
        code: 'PROGRAM_CREATE_FAILED',
      );
    }

    return program;
  }

  Future<Program> update({
    required Session session,
    required String id,
    required String code,
    required String name,
    required String? description,
    required String? fiscalYearId,
    required int fiscalYear,
    required bool isActive,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE programs
        SET
          code = @code,
          name = @name,
          description = @description,
          fiscal_year_id = NULLIF(@fiscal_year_id, '')::uuid,
          fiscal_year = @fiscal_year,
          is_active = @is_active
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'fiscal_year_id': fiscalYearId ?? '',
        'fiscal_year': fiscalYear,
        'is_active': isActive,
      },
    );

    final program = await findById(session, id);
    if (program == null) {
      throw const AppException(
        message: 'Program not found after update.',
        statusCode: 404,
        code: 'PROGRAM_NOT_FOUND',
      );
    }

    return program;
  }

  Future<Program> softDelete({
    required Session session,
    required String id,
    required String deletedBy,
  }) async {
    final current = await findById(session, id);
    if (current == null) {
      throw const AppException(
        message: 'Program not found.',
        statusCode: 404,
        code: 'PROGRAM_NOT_FOUND',
      );
    }

    // تعليق عربي: الحذف هنا ناعم لحماية الأثر المالي، ونمنعه إذا توجد بيانات مرتبطة.
    final blockers = await session.execute(
      Sql.named('''
        SELECT
          (SELECT COUNT(*) FROM budget_sections
           WHERE program_id = @id::uuid AND deleted_at IS NULL) AS sections_count,
          (SELECT COUNT(*) FROM reservations
           WHERE program_id = @id::uuid AND deleted_at IS NULL) AS reservations_count,
          (SELECT COUNT(*) FROM fundings
           WHERE program_id = @id::uuid AND deleted_at IS NULL) AS fundings_count,
          (SELECT COUNT(*) FROM monthly_fundings
           WHERE program_id = @id::uuid AND deleted_at IS NULL) AS monthly_fundings_count,
          (SELECT COUNT(*) FROM financial_transactions
           WHERE program_id = @id::uuid) AS transactions_count
      '''),
      parameters: {'id': id},
    );

    final row = blockers.first;
    final hasRelations = row.any((value) {
      return (int.tryParse(value?.toString() ?? '0') ?? 0) > 0;
    });

    if (hasRelations) {
      throw const AppException(
        message:
            'لا يمكن حذف البرنامج لوجود أبواب أو حجوزات أو حركات مالية مرتبطة به.',
        statusCode: 409,
        code: 'PROGRAM_HAS_RELATED_DATA',
      );
    }

    await session.execute(
      Sql.named('''
        UPDATE programs
        SET
          is_active = FALSE,
          deleted_at = NOW(),
          deleted_by = @deleted_by::uuid
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'deleted_by': deletedBy},
    );

    return current;
  }

  Future<int?> findFiscalYearNumberById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('SELECT year FROM fiscal_years WHERE id = @id::uuid LIMIT 1'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return int.tryParse(result.first[0].toString());
  }
}
