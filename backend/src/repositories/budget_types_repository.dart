import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/budget_type.dart';
import '../models/paged_result.dart';

class BudgetTypesRepository {
  const BudgetTypesRepository();

  static const _uuid = Uuid();

  Future<PagedResult<BudgetType>> list(
    Session session, {
    required String search,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;
    final filterParams = {
      'search': normalizedSearch,
      'pattern': '%$normalizedSearch%',
    };
    final listParams = {...filterParams, 'limit': pageSize, 'offset': offset};

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM budget_types bt
        WHERE @search = ''
          OR bt.code ILIKE @pattern
          OR bt.name ILIKE @pattern
      '''),
      parameters: filterParams,
    );
    final itemsResult = await session.execute(
      Sql.named('''
        SELECT id, code, name, description, is_active, created_at
        FROM budget_types bt
        WHERE @search = ''
          OR bt.code ILIKE @pattern
          OR bt.name ILIKE @pattern
        ORDER BY bt.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: listParams,
    );

    return PagedResult<BudgetType>(
      items: itemsResult
          .map((row) => BudgetType.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<BudgetType?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id, code, name, description, is_active, created_at
        FROM budget_types
        WHERE id = @id::uuid
        LIMIT 1
      '''),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return BudgetType.fromRow(result.first.toColumnMap());
  }

  Future<BudgetType?> findByCode(
    Session session,
    String code, {
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id, code, name, description, is_active, created_at
        FROM budget_types
        WHERE LOWER(code) = LOWER(@code)
          AND (@ignore_id = '' OR id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {'code': code, 'ignore_id': ignoreId ?? ''},
    );
    if (result.isEmpty) return null;
    return BudgetType.fromRow(result.first.toColumnMap());
  }

  Future<BudgetType> create({
    required Session session,
    required String code,
    required String name,
    required String? description,
    required bool isActive,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO budget_types (id, code, name, description, is_active)
        VALUES (@id, @code, @name, @description, @is_active)
      '''),
      parameters: {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'is_active': isActive,
      },
    );
    final budgetType = await findById(session, id);
    if (budgetType == null) {
      throw const AppException(
        message: 'Failed to load created budget type.',
        statusCode: 500,
        code: 'BUDGET_TYPE_CREATE_FAILED',
      );
    }
    return budgetType;
  }

  Future<BudgetType> update({
    required Session session,
    required String id,
    required String code,
    required String name,
    required String? description,
    required bool isActive,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE budget_types
        SET code = @code,
            name = @name,
            description = @description,
            is_active = @is_active
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'is_active': isActive,
      },
    );
    final budgetType = await findById(session, id);
    if (budgetType == null) {
      throw const AppException(
        message: 'Budget type not found after update.',
        statusCode: 404,
        code: 'BUDGET_TYPE_NOT_FOUND',
      );
    }
    return budgetType;
  }

  Future<void> delete(Session session, String id) async {
    final usage = await session.execute(
      Sql.named('''
        SELECT
          (SELECT COUNT(*) FROM budget_sections WHERE budget_type_id = @id::uuid) +
          (SELECT COUNT(*) FROM fundings WHERE budget_type_id = @id::uuid) +
          (SELECT COUNT(*) FROM reservations WHERE budget_type_id = @id::uuid) +
          (SELECT COUNT(*) FROM monthly_fundings WHERE budget_type_id = @id::uuid) AS total
      '''),
      parameters: {'id': id},
    );
    if (int.parse(usage.first[0].toString()) > 0) {
      throw const AppException(
        message: 'Budget type has related financial records.',
        statusCode: 422,
        code: 'BUDGET_TYPE_IN_USE',
      );
    }
    await session.execute(
      Sql.named('DELETE FROM budget_types WHERE id = @id::uuid'),
      parameters: {'id': id},
    );
  }
}
