import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/app_user.dart';

class AuthRepository {
  const AuthRepository();

  static const _uuid = Uuid();

  Future<AppUser?> findByIdentity(Session session, String identity) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.full_name,
          u.email,
          u.password_hash,
          u.is_active,
          r.id AS role_id,
          r.code AS role_code,
          r.name AS role_name
        FROM users u
        INNER JOIN roles r ON r.id = u.role_id
        WHERE LOWER(u.username) = LOWER(@identity)
           OR LOWER(u.email) = LOWER(@identity)
        LIMIT 1
      '''),
      parameters: {'identity': identity},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first.toColumnMap();
    final permissions = await findPermissionCodes(
      session,
      row['role_id'].toString(),
    );

    return AppUser.fromRow(row, permissions: permissions);
  }

  Future<AppUser?> findById(Session session, String userId) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.full_name,
          u.email,
          u.password_hash,
          u.is_active,
          r.id AS role_id,
          r.code AS role_code,
          r.name AS role_name
        FROM users u
        INNER JOIN roles r ON r.id = u.role_id
        WHERE u.id = @user_id
        LIMIT 1
      '''),
      parameters: {'user_id': userId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first.toColumnMap();
    final permissions = await findPermissionCodes(
      session,
      row['role_id'].toString(),
    );

    return AppUser.fromRow(row, permissions: permissions);
  }

  Future<List<String>> findPermissionCodes(
    Session session,
    String roleId,
  ) async {
    final result = await session.execute(
      Sql.named('''
        SELECT p.code
        FROM role_permissions rp
        INNER JOIN permissions p ON p.id = rp.permission_id
        WHERE rp.role_id = @role_id::uuid
        ORDER BY p.code ASC
      '''),
      parameters: {'role_id': roleId},
    );

    return result.map((row) => row[0].toString()).toList();
  }

  Future<String> findRoleIdByCode(Session session, String roleCode) async {
    final result = await session.execute(
      Sql.named('''
        SELECT id
        FROM roles
        WHERE LOWER(code) = LOWER(@role_code)
        LIMIT 1
      '''),
      parameters: {'role_code': roleCode},
    );

    if (result.isEmpty) {
      throw const AppException(
        message: 'Role not found.',
        statusCode: 500,
        code: 'ROLE_NOT_FOUND',
      );
    }

    return result.first[0].toString();
  }

  Future<String> createUser({
    required Session session,
    required String username,
    required String fullName,
    required String email,
    required String passwordHash,
    required String roleId,
  }) async {
    final userId = _uuid.v4();

    await session.execute(
      Sql.named('''
        INSERT INTO users (
          id,
          username,
          full_name,
          email,
          password_hash,
          role_id,
          is_active
        )
        VALUES (
          @id,
          @username,
          @full_name,
          @email,
          @password_hash,
          @role_id,
          TRUE
        )
      '''),
      parameters: {
        'id': userId,
        'username': username,
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'role_id': roleId,
      },
    );

    return userId;
  }
}
