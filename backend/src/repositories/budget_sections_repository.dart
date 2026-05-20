import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/budget_section.dart';
import '../models/paged_result.dart';

class BudgetSectionsRepository {
  const BudgetSectionsRepository();

  static const _uuid = Uuid();

  static const _sectionTotalsCte = '''
    WITH RECURSIVE section_descendants AS (
      SELECT
        bs.id AS section_id,
        bs.id AS descendant_id
      FROM budget_sections bs
      WHERE bs.deleted_at IS NULL
      UNION ALL
      SELECT
        sd.section_id,
        child.id AS descendant_id
      FROM section_descendants sd
      INNER JOIN budget_sections child ON child.parent_id = sd.descendant_id
      WHERE child.deleted_at IS NULL
    ),
    section_totals AS (
      SELECT
        sd.section_id,
        COALESCE(SUM(
          CASE
            WHEN leaf.is_postable THEN COALESCE(leaf.allocated_amount, 0)
            ELSE 0
          END
        ), 0) AS total_allocated_amount
      FROM section_descendants sd
      INNER JOIN budget_sections leaf ON leaf.id = sd.descendant_id
      GROUP BY sd.section_id
    )
  ''';

  Future<PagedResult<BudgetSection>> list(
    Session session, {
    required String search,
    required String? programId,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM budget_sections bs
        INNER JOIN programs p ON p.id = bs.program_id
        WHERE
          bs.deleted_at IS NULL
          AND (@program_id = '' OR bs.program_id = @program_id::uuid)
          AND (@fiscal_year_id = '' OR bs.fiscal_year_id = @fiscal_year_id::uuid)
          AND (@budget_type_id = '' OR bs.budget_type_id = @budget_type_id::uuid)
          AND (
            @search = ''
            OR LOWER(bs.code) LIKE LOWER(@pattern)
            OR LOWER(bs.name) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
          )
      '''),
      parameters: {
        'program_id': programId ?? '',
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
      },
    );

    final itemsResult = await session.execute(
      Sql.named('''
        $_sectionTotalsCte
        SELECT
          bs.id,
          bs.program_id,
          p.code AS program_code,
          p.name AS program_name,
          bs.fiscal_year_id,
          fy.year AS fiscal_year,
          fy.name AS fiscal_year_name,
          bs.budget_type_id,
          bt.code AS budget_type_code,
          bt.name AS budget_type_name,
          bs.parent_id,
          bs.level,
          bs.full_code,
          bs.is_postable,
          bs.sort_order,
          bs.path,
          bs.code,
          bs.name,
          bs.description,
          bs.allocated_amount,
          COALESCE(MAX(st.total_allocated_amount), bs.allocated_amount, 0) AS total_allocated_amount,
          bs.is_active,
          bs.created_at,
          COUNT(DISTINCT f.id) AS fundings_count,
          COUNT(DISTINCT child.id) AS children_count
        FROM budget_sections bs
        INNER JOIN programs p ON p.id = bs.program_id
        LEFT JOIN fiscal_years fy ON fy.id = bs.fiscal_year_id
        LEFT JOIN budget_types bt ON bt.id = bs.budget_type_id
        LEFT JOIN fundings f ON f.budget_section_id = bs.id
        LEFT JOIN budget_sections child ON child.parent_id = bs.id
          AND child.deleted_at IS NULL
        LEFT JOIN section_totals st ON st.section_id = bs.id
        WHERE
          bs.deleted_at IS NULL
          AND (@program_id = '' OR bs.program_id = @program_id::uuid)
          AND (@fiscal_year_id = '' OR bs.fiscal_year_id = @fiscal_year_id::uuid)
          AND (@budget_type_id = '' OR bs.budget_type_id = @budget_type_id::uuid)
          AND (
            @search = ''
            OR LOWER(bs.code) LIKE LOWER(@pattern)
            OR LOWER(COALESCE(bs.full_code, '')) LIKE LOWER(@pattern)
            OR LOWER(bs.name) LIKE LOWER(@pattern)
            OR LOWER(p.name) LIKE LOWER(@pattern)
          )
        GROUP BY bs.id, p.id, fy.id, bt.id
        ORDER BY p.code, COALESCE(bs.path, bs.id::text), bs.sort_order, bs.code
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'program_id': programId ?? '',
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    final items = itemsResult
        .map((row) => BudgetSection.fromRow(row.toColumnMap()))
        .toList();

    return PagedResult<BudgetSection>(
      items: items,
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<BudgetSection?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        $_sectionTotalsCte
        SELECT
          bs.id,
          bs.program_id,
          p.code AS program_code,
          p.name AS program_name,
          bs.fiscal_year_id,
          fy.year AS fiscal_year,
          fy.name AS fiscal_year_name,
          bs.budget_type_id,
          bt.code AS budget_type_code,
          bt.name AS budget_type_name,
          bs.parent_id,
          bs.level,
          bs.full_code,
          bs.is_postable,
          bs.sort_order,
          bs.path,
          bs.code,
          bs.name,
          bs.description,
          bs.allocated_amount,
          COALESCE(MAX(st.total_allocated_amount), bs.allocated_amount, 0) AS total_allocated_amount,
          bs.is_active,
          bs.created_at,
          COUNT(DISTINCT f.id) AS fundings_count,
          COUNT(DISTINCT child.id) AS children_count
        FROM budget_sections bs
        INNER JOIN programs p ON p.id = bs.program_id
        LEFT JOIN fiscal_years fy ON fy.id = bs.fiscal_year_id
        LEFT JOIN budget_types bt ON bt.id = bs.budget_type_id
        LEFT JOIN fundings f ON f.budget_section_id = bs.id
        LEFT JOIN budget_sections child ON child.parent_id = bs.id
          AND child.deleted_at IS NULL
        LEFT JOIN section_totals st ON st.section_id = bs.id
        WHERE bs.id = @id::uuid
          AND bs.deleted_at IS NULL
        GROUP BY bs.id, p.id, fy.id, bt.id
        LIMIT 1
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) {
      return null;
    }

    return BudgetSection.fromRow(result.first.toColumnMap());
  }

  Future<BudgetSection?> findByCode(
    Session session, {
    required String programId,
    required String? fiscalYearId,
    required String code,
    String? parentId,
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          bs.id,
          bs.program_id,
          p.code AS program_code,
          p.name AS program_name,
          bs.fiscal_year_id,
          fy.year AS fiscal_year,
          fy.name AS fiscal_year_name,
          bs.budget_type_id,
          bt.code AS budget_type_code,
          bt.name AS budget_type_name,
          bs.parent_id,
          bs.level,
          bs.full_code,
          bs.is_postable,
          bs.sort_order,
          bs.path,
          bs.code,
          bs.name,
          bs.description,
          bs.allocated_amount,
          bs.allocated_amount AS total_allocated_amount,
          bs.is_active,
          bs.created_at,
          0 AS fundings_count,
          0 AS children_count
        FROM budget_sections bs
        INNER JOIN programs p ON p.id = bs.program_id
        LEFT JOIN fiscal_years fy ON fy.id = bs.fiscal_year_id
        LEFT JOIN budget_types bt ON bt.id = bs.budget_type_id
        WHERE bs.program_id = @program_id::uuid
          AND (@fiscal_year_id = '' OR bs.fiscal_year_id = @fiscal_year_id::uuid)
          AND (
            (@parent_id = '' AND bs.parent_id IS NULL)
            OR bs.parent_id = NULLIF(@parent_id, '')::uuid
          )
          AND LOWER(bs.code) = LOWER(@code)
          AND (@ignore_id = '' OR bs.id <> @ignore_id::uuid)
          AND bs.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {
        'program_id': programId,
        'fiscal_year_id': fiscalYearId ?? '',
        'parent_id': parentId ?? '',
        'code': code,
        'ignore_id': ignoreId ?? '',
      },
    );

    if (result.isEmpty) {
      return null;
    }

    return BudgetSection.fromRow(result.first.toColumnMap());
  }

  Future<void> ensurePostable(Session session, String id) async {
    final section = await findById(session, id);
    if (section == null || !section.isActive) {
      throw const AppException(
        message: 'الباب المالي غير موجود أو غير فعال.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    if (!section.isPostable) {
      throw const AppException(
        message:
            'لا يمكن تنفيذ عمليات مالية على باب تجميعي. اختر باباً نهائياً.',
        statusCode: 422,
        code: 'SECTION_NOT_POSTABLE',
      );
    }
  }

  Future<String> ensureBudgetTypeForProgram(
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
    if (existingByName.isNotEmpty) {
      return existingByName.first[0].toString();
    }

    final existingByCode = await session.execute(
      Sql.named('''
        SELECT id
        FROM budget_types
        WHERE LOWER(code) = LOWER(@code)
        LIMIT 1
      '''),
      parameters: {'code': programCode},
    );
    if (existingByCode.isNotEmpty) {
      return existingByCode.first[0].toString();
    }

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

  Future<BudgetSection> create({
    required Session session,
    required String programId,
    required String fiscalYearId,
    required String budgetTypeId,
    required String? parentId,
    required String code,
    required String name,
    required String? description,
    required double allocatedAmount,
    required bool isPostable,
    required int sortOrder,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final hierarchy = await _resolveHierarchy(
      session: session,
      id: id,
      programId: programId,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
      parentId: parentId,
      code: code,
    );

    await _validatePostableState(
      session: session,
      id: id,
      parentId: parentId,
      allocatedAmount: allocatedAmount,
      isPostable: isPostable,
    );

    await session.execute(
      Sql.named('''
        INSERT INTO budget_sections (
          id,
          program_id,
          fiscal_year_id,
          budget_type_id,
          parent_id,
          level,
          full_code,
          is_postable,
          sort_order,
          path,
          code,
          name,
          description,
          allocated_amount,
          is_active,
          created_by
        ) VALUES (
          @id,
          @program_id::uuid,
          @fiscal_year_id::uuid,
          @budget_type_id::uuid,
          NULLIF(@parent_id, '')::uuid,
          @level,
          @full_code,
          @is_postable,
          @sort_order,
          @path,
          @code,
          @name,
          @description,
          @allocated_amount,
          TRUE,
          @created_by::uuid
        )
      '''),
      parameters: {
        'id': id,
        'program_id': programId,
        'fiscal_year_id': fiscalYearId,
        'budget_type_id': budgetTypeId,
        'parent_id': parentId ?? '',
        'level': hierarchy.level,
        'full_code': hierarchy.fullCode,
        'is_postable': isPostable,
        'sort_order': sortOrder,
        'path': hierarchy.path,
        'code': code,
        'name': name,
        'description': description,
        'allocated_amount': allocatedAmount,
        'created_by': createdBy,
      },
    );

    final budgetSection = await findById(session, id);
    if (budgetSection == null) {
      throw const AppException(
        message: 'Failed to load created budget section.',
        statusCode: 500,
        code: 'BUDGET_SECTION_CREATE_FAILED',
      );
    }

    return budgetSection;
  }

  Future<BudgetSection> update({
    required Session session,
    required String id,
    required String programId,
    required String fiscalYearId,
    required String budgetTypeId,
    required String? parentId,
    required String code,
    required String name,
    required String? description,
    required double allocatedAmount,
    required bool isPostable,
    required int sortOrder,
    required bool isActive,
  }) async {
    final hierarchy = await _resolveHierarchy(
      session: session,
      id: id,
      programId: programId,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
      parentId: parentId,
      code: code,
    );

    if (parentId != null && parentId.isNotEmpty) {
      await _ensureParentIsNotDescendant(session, id, parentId);
    }

    await _validatePostableState(
      session: session,
      id: id,
      parentId: parentId,
      allocatedAmount: allocatedAmount,
      isPostable: isPostable,
    );

    await session.execute(
      Sql.named('''
        UPDATE budget_sections
        SET
          program_id = @program_id::uuid,
          fiscal_year_id = @fiscal_year_id::uuid,
          budget_type_id = @budget_type_id::uuid,
          parent_id = NULLIF(@parent_id, '')::uuid,
          level = @level,
          full_code = @full_code,
          is_postable = @is_postable,
          sort_order = @sort_order,
          path = @path,
          code = @code,
          name = @name,
          description = @description,
          allocated_amount = @allocated_amount,
          is_active = @is_active
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'program_id': programId,
        'fiscal_year_id': fiscalYearId,
        'budget_type_id': budgetTypeId,
        'parent_id': parentId ?? '',
        'level': hierarchy.level,
        'full_code': hierarchy.fullCode,
        'is_postable': isPostable,
        'sort_order': sortOrder,
        'path': hierarchy.path,
        'code': code,
        'name': name,
        'description': description,
        'allocated_amount': allocatedAmount,
        'is_active': isActive,
      },
    );

    await _rebuildDescendantPaths(session, id);

    final budgetSection = await findById(session, id);
    if (budgetSection == null) {
      throw const AppException(
        message: 'Budget section not found after update.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    return budgetSection;
  }

  Future<BudgetSection> softDelete({
    required Session session,
    required String id,
    required String deletedBy,
  }) async {
    final current = await findById(session, id);
    if (current == null) {
      throw const AppException(
        message: 'Budget section not found.',
        statusCode: 404,
        code: 'BUDGET_SECTION_NOT_FOUND',
      );
    }

    // تعليق عربي: الباب لا يحذف إذا دخل في دورة مالية حتى لا تتكسر التقارير والسجل.
    final blockers = await session.execute(
      Sql.named('''
        SELECT
          (SELECT COUNT(*) FROM reservations
           WHERE budget_section_id = @id::uuid AND deleted_at IS NULL) AS reservations_count,
          (SELECT COUNT(*) FROM fundings
           WHERE budget_section_id = @id::uuid AND deleted_at IS NULL) AS fundings_count,
          (SELECT COUNT(*) FROM monthly_fundings
           WHERE section_id = @id::uuid AND deleted_at IS NULL) AS monthly_fundings_count,
          (SELECT COUNT(*) FROM financial_transactions
           WHERE COALESCE(section_id, budget_section_id) = @id::uuid) AS transactions_count,
          (SELECT COUNT(*) FROM budget_sections
           WHERE parent_id = @id::uuid AND deleted_at IS NULL) AS children_count
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
            'لا يمكن حذف الباب لوجود حجوزات أو تخصيصات أو حركات مالية مرتبطة به.',
        statusCode: 409,
        code: 'BUDGET_SECTION_HAS_RELATED_DATA',
      );
    }

    await session.execute(
      Sql.named('''
        UPDATE budget_sections
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

  Future<_HierarchyValues> _resolveHierarchy({
    required Session session,
    required String id,
    required String programId,
    required String fiscalYearId,
    required String budgetTypeId,
    required String? parentId,
    required String code,
  }) async {
    if (parentId == null || parentId.isEmpty) {
      return _HierarchyValues(level: 1, fullCode: code, path: id);
    }

    final parent = await findById(session, parentId);
    if (parent == null || !parent.isActive) {
      throw const AppException(
        message: 'الباب الأب غير موجود أو غير فعال.',
        statusCode: 422,
        code: 'INVALID_PARENT_SECTION',
      );
    }

    if (parent.programId != programId ||
        parent.fiscalYearId != fiscalYearId ||
        parent.budgetTypeId != budgetTypeId) {
      throw const AppException(
        message: 'الباب الأب يجب أن يكون ضمن نفس البرنامج والسنة المالية.',
        statusCode: 422,
        code: 'PARENT_SECTION_SCOPE_MISMATCH',
      );
    }

    return _HierarchyValues(
      level: parent.level + 1,
      fullCode: '${parent.fullCode} $code'.trim(),
      path: '${parent.path ?? parent.id}/$id',
    );
  }

  Future<void> _validatePostableState({
    required Session session,
    required String id,
    required String? parentId,
    required double allocatedAmount,
    required bool isPostable,
  }) async {
    if (!isPostable && allocatedAmount > 0) {
      throw const AppException(
        message: 'الأبواب التجميعية لا تقبل تخصيصاً مباشراً.',
        statusCode: 422,
        code: 'PARENT_SECTION_CANNOT_HAVE_ALLOCATION',
      );
    }

    if (isPostable) {
      final children = await session.execute(
        Sql.named('''
          SELECT COUNT(*)
          FROM budget_sections
          WHERE parent_id = @id::uuid
            AND deleted_at IS NULL
        '''),
        parameters: {'id': id},
      );
      final count = int.tryParse(children.first[0].toString()) ?? 0;
      if (count > 0) {
        throw const AppException(
          message: 'الباب الذي يحتوي أبواباً فرعية يجب أن يكون تجميعياً.',
          statusCode: 422,
          code: 'SECTION_WITH_CHILDREN_MUST_BE_PARENT',
        );
      }
    }

    if (parentId != null && parentId.isNotEmpty) {
      final parent = await findById(session, parentId);
      if (parent != null && parent.isPostable) {
        if (parent.allocatedAmount > 0 ||
            await _hasFinancialActivity(session, parentId)) {
          throw const AppException(
            message:
                'لا يمكن إضافة فرع تحت باب عليه تخصيص أو حركات مالية مباشرة.',
            statusCode: 409,
            code: 'PARENT_SECTION_HAS_DIRECT_ACTIVITY',
          );
        }

        // تعليق عربي: عند إضافة أول فرع يصبح الباب الأب تجميعياً تلقائياً.
        await session.execute(
          Sql.named('''
            UPDATE budget_sections
            SET is_postable = FALSE,
                allocated_amount = 0
            WHERE id = @parent_id::uuid
          '''),
          parameters: {'parent_id': parentId},
        );
      }
    }
  }

  Future<bool> _hasFinancialActivity(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT EXISTS (
          SELECT 1 FROM reservations
          WHERE budget_section_id = @id::uuid AND deleted_at IS NULL
          UNION ALL
          SELECT 1 FROM fundings
          WHERE budget_section_id = @id::uuid AND deleted_at IS NULL
          UNION ALL
          SELECT 1 FROM financial_transactions
          WHERE COALESCE(section_id, budget_section_id) = @id::uuid
          LIMIT 1
        )
      '''),
      parameters: {'id': id},
    );
    return result.first[0] == true;
  }

  Future<void> _ensureParentIsNotDescendant(
    Session session,
    String id,
    String parentId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        WITH current_section AS (
          SELECT path FROM budget_sections WHERE id = @id::uuid LIMIT 1
        )
        SELECT EXISTS (
          SELECT 1
          FROM budget_sections bs, current_section cs
          WHERE bs.id = @parent_id::uuid
            AND bs.path LIKE cs.path || '/%'
        )
      '''),
      parameters: {'id': id, 'parent_id': parentId},
    );
    if (result.first[0] == true) {
      throw const AppException(
        message: 'لا يمكن نقل الباب تحت أحد فروعه.',
        statusCode: 422,
        code: 'INVALID_SECTION_MOVE',
      );
    }
  }

  Future<void> _rebuildDescendantPaths(Session session, String id) async {
    await session.execute(
      Sql.named('''
        WITH RECURSIVE tree AS (
          SELECT id, level, full_code, path
          FROM budget_sections
          WHERE id = @id::uuid
          UNION ALL
          SELECT
            child.id,
            tree.level + 1,
            TRIM(tree.full_code || ' ' || child.code),
            tree.path || '/' || child.id::text
          FROM budget_sections child
          INNER JOIN tree ON child.parent_id = tree.id
          WHERE child.deleted_at IS NULL
        )
        UPDATE budget_sections bs
        SET level = tree.level,
            full_code = tree.full_code,
            path = tree.path
        FROM tree
        WHERE bs.id = tree.id
      '''),
      parameters: {'id': id},
    );
  }
}

class _HierarchyValues {
  const _HierarchyValues({
    required this.level,
    required this.fullCode,
    required this.path,
  });

  final int level;
  final String fullCode;
  final String path;
}
