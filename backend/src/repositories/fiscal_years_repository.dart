import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/fiscal_year.dart';
import '../models/paged_result.dart';

class FiscalYearsRepository {
  const FiscalYearsRepository();

  static const _uuid = Uuid();

  Future<PagedResult<FiscalYear>> list(
    Session session, {
    required String search,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM fiscal_years fy
        WHERE @search = ''
          OR fy.name ILIKE @pattern
          OR fy.year::text ILIKE @pattern
      '''),
      parameters: {
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
      },
    );

    final itemsResult = await session.execute(
      Sql.named('''
        SELECT id, year, name, start_date, end_date, is_active, created_at
        FROM fiscal_years fy
        WHERE @search = ''
          OR fy.name ILIKE @pattern
          OR fy.year::text ILIKE @pattern
        ORDER BY fy.year DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'limit': pageSize,
        'offset': offset,
      },
    );

    return PagedResult<FiscalYear>(
      items: itemsResult
          .map((row) => FiscalYear.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<FiscalYear?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id, year, name, start_date, end_date, is_active, created_at
        FROM fiscal_years
        WHERE id = @id::uuid
        LIMIT 1
      '''),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return FiscalYear.fromRow(result.first.toColumnMap());
  }

  Future<FiscalYear?> findByYear(
    Session session,
    int year, {
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id, year, name, start_date, end_date, is_active, created_at
        FROM fiscal_years
        WHERE year = @year
          AND (@ignore_id = '' OR id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {'year': year, 'ignore_id': ignoreId ?? ''},
    );
    if (result.isEmpty) return null;
    return FiscalYear.fromRow(result.first.toColumnMap());
  }

  Future<FiscalYear> create({
    required Session session,
    required int year,
    required String name,
    required String startDate,
    required String endDate,
    required bool isActive,
  }) async {
    final id = _uuid.v4();
    if (isActive) {
      await session.execute('UPDATE fiscal_years SET is_active = FALSE');
    }
    await session.execute(
      Sql.named('''
        INSERT INTO fiscal_years (id, year, name, start_date, end_date, is_active)
        VALUES (@id, @year, @name, @start_date::date, @end_date::date, @is_active)
      '''),
      parameters: {
        'id': id,
        'year': year,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'is_active': isActive,
      },
    );

    final fiscalYear = await findById(session, id);
    if (fiscalYear == null) {
      throw const AppException(
        message: 'Failed to load created fiscal year.',
        statusCode: 500,
        code: 'FISCAL_YEAR_CREATE_FAILED',
      );
    }
    return fiscalYear;
  }

  Future<FiscalYear> update({
    required Session session,
    required String id,
    required int year,
    required String name,
    required String startDate,
    required String endDate,
    required bool isActive,
  }) async {
    if (isActive) {
      await session.execute(
        Sql.named(
          'UPDATE fiscal_years SET is_active = FALSE WHERE id <> @id::uuid',
        ),
        parameters: {'id': id},
      );
    }
    await session.execute(
      Sql.named('''
        UPDATE fiscal_years
        SET year = @year,
            name = @name,
            start_date = @start_date::date,
            end_date = @end_date::date,
            is_active = @is_active
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'year': year,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'is_active': isActive,
      },
    );
    final fiscalYear = await findById(session, id);
    if (fiscalYear == null) {
      throw const AppException(
        message: 'Fiscal year not found after update.',
        statusCode: 404,
        code: 'FISCAL_YEAR_NOT_FOUND',
      );
    }
    return fiscalYear;
  }

  Future<FiscalYear> activate(Session session, String id) async {
    await session.execute('UPDATE fiscal_years SET is_active = FALSE');
    await session.execute(
      Sql.named(
        'UPDATE fiscal_years SET is_active = TRUE WHERE id = @id::uuid',
      ),
      parameters: {'id': id},
    );
    final fiscalYear = await findById(session, id);
    if (fiscalYear == null) {
      throw const AppException(
        message: 'Fiscal year not found after activation.',
        statusCode: 404,
        code: 'FISCAL_YEAR_NOT_FOUND',
      );
    }
    return fiscalYear;
  }

  Future<void> delete(Session session, String id) async {
    final usage = await session.execute(
      Sql.named('''
        SELECT
          (SELECT COUNT(*) FROM programs WHERE fiscal_year_id = @id::uuid) +
          (SELECT COUNT(*) FROM fundings WHERE fiscal_year_id = @id::uuid) +
          (SELECT COUNT(*) FROM reservations WHERE fiscal_year_id = @id::uuid) +
          (SELECT COUNT(*) FROM monthly_fundings WHERE fiscal_year_id = @id::uuid) AS total
      '''),
      parameters: {'id': id},
    );
    if (int.parse(usage.first[0].toString()) > 0) {
      throw const AppException(
        message: 'Fiscal year has related financial records.',
        statusCode: 422,
        code: 'FISCAL_YEAR_IN_USE',
      );
    }
    await session.execute(
      Sql.named('DELETE FROM fiscal_years WHERE id = @id::uuid'),
      parameters: {'id': id},
    );
  }
}
