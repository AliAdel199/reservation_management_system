import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/managed_user.dart';
import '../models/paged_result.dart';

class UsersRepository {
  const UsersRepository();

  static const _uuid = Uuid();

  Future<PagedResult<ManagedUser>> list(
    Session session, {
    required String search,
    required String? roleId,
    required bool? isActive,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSearch = search.trim();
    final normalizedRoleId = roleId?.trim() ?? '';
    final offset = (page - 1) * pageSize;

    final totalResult = await session.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM users u
        JOIN roles r ON r.id = u.role_id
        WHERE
          (@search = ''
            OR LOWER(u.username) LIKE LOWER(@pattern)
            OR LOWER(u.full_name) LIKE LOWER(@pattern)
            OR LOWER(u.email) LIKE LOWER(@pattern))
          AND (@role_id = '' OR u.role_id = @role_id::uuid)
          AND (@active_filter = '' OR u.is_active = @is_active)
      '''),
      parameters: {
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'role_id': normalizedRoleId,
        'active_filter': isActive == null ? '' : 'set',
        'is_active': isActive ?? true,
      },
    );

    final result = await session.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.full_name,
          u.email,
          u.role_id,
          r.code AS role_code,
          r.name AS role_name,
          u.is_active,
          u.created_at
        FROM users u
        JOIN roles r ON r.id = u.role_id
        WHERE
          (@search = ''
            OR LOWER(u.username) LIKE LOWER(@pattern)
            OR LOWER(u.full_name) LIKE LOWER(@pattern)
            OR LOWER(u.email) LIKE LOWER(@pattern))
          AND (@role_id = '' OR u.role_id = @role_id::uuid)
          AND (@active_filter = '' OR u.is_active = @is_active)
        ORDER BY u.created_at DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'search': normalizedSearch,
        'pattern': '%$normalizedSearch%',
        'role_id': normalizedRoleId,
        'active_filter': isActive == null ? '' : 'set',
        'is_active': isActive ?? true,
        'limit': pageSize,
        'offset': offset,
      },
    );

    return PagedResult<ManagedUser>(
      items: result
          .map((row) => ManagedUser.fromRow(row.toColumnMap()))
          .toList(),
      total: int.parse(totalResult.first[0].toString()),
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<UserRole>> roles(Session session) async {
    final result = await session.execute('''
      SELECT id, code, name, description
      FROM roles
      ORDER BY name ASC
    ''');
    return result.map((row) => UserRole.fromRow(row.toColumnMap())).toList();
  }

  Future<ManagedUser?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.full_name,
          u.email,
          u.role_id,
          r.code AS role_code,
          r.name AS role_name,
          u.is_active,
          u.created_at
        FROM users u
        JOIN roles r ON r.id = u.role_id
        WHERE u.id = @id::uuid
        LIMIT 1
      '''),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return ManagedUser.fromRow(result.first.toColumnMap());
  }

  Future<void> ensureUniqueIdentity(
    Session session, {
    required String username,
    required String email,
    String? ignoreId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id
        FROM users
        WHERE (LOWER(username) = LOWER(@username) OR LOWER(email) = LOWER(@email))
          AND (@ignore_id = '' OR id <> @ignore_id::uuid)
        LIMIT 1
      '''),
      parameters: {
        'username': username,
        'email': email,
        'ignore_id': ignoreId ?? '',
      },
    );

    if (result.isNotEmpty) {
      throw const AppException(
        message: 'Username or email already exists.',
        statusCode: 409,
        code: 'USER_IDENTITY_EXISTS',
      );
    }
  }

  Future<ManagedUser> create({
    required Session session,
    required String username,
    required String fullName,
    required String email,
    required String passwordHash,
    required String roleId,
  }) async {
    final id = _uuid.v4();
    await session.execute(
      Sql.named('''
        INSERT INTO users (id, username, full_name, email, password_hash, role_id)
        VALUES (@id, @username, @full_name, @email, @password_hash, @role_id::uuid)
      '''),
      parameters: {
        'id': id,
        'username': username,
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'role_id': roleId,
      },
    );

    final user = await findById(session, id);
    if (user == null) {
      throw const AppException(
        message: 'Failed to load created user.',
        statusCode: 500,
        code: 'USER_CREATE_FAILED',
      );
    }
    return user;
  }

  Future<ManagedUser> update({
    required Session session,
    required String id,
    required String username,
    required String fullName,
    required String email,
    required String roleId,
    required bool isActive,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE users
        SET
          username = @username,
          full_name = @full_name,
          email = @email,
          role_id = @role_id::uuid,
          is_active = @is_active,
          updated_at = NOW()
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': id,
        'username': username,
        'full_name': fullName,
        'email': email,
        'role_id': roleId,
        'is_active': isActive,
      },
    );

    final user = await findById(session, id);
    if (user == null) {
      throw const AppException(
        message: 'User not found after update.',
        statusCode: 404,
        code: 'USER_NOT_FOUND',
      );
    }
    return user;
  }

  Future<ManagedUser> setStatus({
    required Session session,
    required String id,
    required bool isActive,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE users
        SET is_active = @is_active, updated_at = NOW()
        WHERE id = @id::uuid
      '''),
      parameters: {'id': id, 'is_active': isActive},
    );

    final user = await findById(session, id);
    if (user == null) {
      throw const AppException(
        message: 'User not found after status update.',
        statusCode: 404,
        code: 'USER_NOT_FOUND',
      );
    }
    return user;
  }

  Future<void> updatePassword({
    required Session session,
    required String id,
    required String passwordHash,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE users
        SET password_hash = @password_hash, updated_at = NOW()
        WHERE id = @id::uuid
      '''),
      parameters: {'id': id, 'password_hash': passwordHash},
    );
  }
}
