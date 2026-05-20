import 'package:postgres/postgres.dart';

import '../models/audit_log_item.dart';
import '../models/paged_result.dart';

class AuditLogsRepository {
  const AuditLogsRepository();

  Future<PagedResult<AuditLogItem>> list(
    Session session, {
    required String search,
    required String action,
    required String entityType,
    required String? userId,
    required String? dateFrom,
    required String? dateTo,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final normalizedAction = action.trim();
    final normalizedEntityType = entityType.trim();
    final normalizedUserId = userId?.trim() ?? '';
    final offset = (page - 1) * pageSize;

    final whereParts = <String>[
      '''
      (@search = ''
        OR LOWER(al.action) LIKE LOWER(@pattern)
        OR LOWER(COALESCE(al.description, '')) LIKE LOWER(@pattern)
        OR LOWER(COALESCE(u.username, '')) LIKE LOWER(@pattern)
        OR LOWER(COALESCE(u.full_name, '')) LIKE LOWER(@pattern))
      ''',
    ];

    final filterParameters = <String, dynamic>{
      'search': normalizedSearch,
      'pattern': '%$normalizedSearch%',
    };

    final listParameters = <String, dynamic>{
      ...filterParameters,
      'limit': pageSize,
      'offset': offset,
    };

    if (normalizedAction.isNotEmpty) {
      whereParts.add('al.action = @action');
      filterParameters['action'] = normalizedAction;
      listParameters['action'] = normalizedAction;
    }

    if (normalizedEntityType.isNotEmpty) {
      whereParts.add('al.entity_name = @entity_type');
      filterParameters['entity_type'] = normalizedEntityType;
      listParameters['entity_type'] = normalizedEntityType;
    }

    if (normalizedUserId.isNotEmpty) {
      whereParts.add('al.created_by = @user_id::uuid');
      filterParameters['user_id'] = normalizedUserId;
      listParameters['user_id'] = normalizedUserId;
    }

    if (dateFrom != null && dateFrom.trim().isNotEmpty) {
      whereParts.add('al.created_at::date >= @date_from::date');
      filterParameters['date_from'] = dateFrom.trim();
      listParameters['date_from'] = dateFrom.trim();
    }

    if (dateTo != null && dateTo.trim().isNotEmpty) {
      whereParts.add('al.created_at::date <= @date_to::date');
      filterParameters['date_to'] = dateTo.trim();
      listParameters['date_to'] = dateTo.trim();
    }

    final whereSql = whereParts.join('\n          AND ');

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM audit_logs al
        LEFT JOIN users u ON u.id = al.created_by
        WHERE $whereSql
      '''),
      parameters: filterParameters,
    );

    final result = await session.execute(
      Sql.named('''
        SELECT
          al.id,
          al.action,
          al.entity_name AS entity_type,
          al.entity_id,
          al.description,
          al.ip_address,
          al.created_at,
          u.username,
          u.full_name
        FROM audit_logs al
        LEFT JOIN users u ON u.id = al.created_by
        WHERE $whereSql
        ORDER BY al.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: listParameters,
    );

    return PagedResult<AuditLogItem>(
      items: result
          .map((row) => AuditLogItem.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }
}
