import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/users_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';
import '../services/password_service.dart';

class UsersController {
  const UsersController({
    required DatabaseService database,
    required UsersRepository usersRepository,
    required PasswordService passwordService,
    required AuditService auditService,
  }) : _database = database,
       _usersRepository = usersRepository,
       _passwordService = passwordService,
       _auditService = auditService;

  final DatabaseService _database;
  final UsersRepository _usersRepository;
  final PasswordService _passwordService;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final search = request.url.queryParameters['search'] ?? '';
    final roleId = request.url.queryParameters['role_id'];
    final active = request.url.queryParameters['is_active'];
    final isActive = active == null || active.isEmpty
        ? null
        : active.toLowerCase() == 'true';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final pageSize =
        int.tryParse(request.url.queryParameters['page_size'] ?? '10') ?? 10;

    final result = await _usersRepository.list(
      _database.connection,
      search: search,
      roleId: roleId,
      isActive: isActive,
      page: page < 1 ? 1 : page,
      pageSize: pageSize < 1 ? 10 : pageSize,
    );

    return jsonResponse(
      200,
      message: 'Users retrieved successfully.',
      data: result.toJson((item) => item.toJson()),
    );
  }

  Future<Response> roles(Request request) async {
    final roles = await _usersRepository.roles(_database.connection);
    return jsonResponse(
      200,
      message: 'Roles retrieved successfully.',
      data: {'items': roles.map((role) => role.toJson()).toList()},
    );
  }

  Future<Response> create(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final username = body['username']?.toString().trim() ?? '';
    final fullName = body['full_name']?.toString().trim() ?? '';
    final email = body['email']?.toString().trim() ?? '';
    final password = body['password']?.toString() ?? '';
    final roleId = body['role_id']?.toString().trim() ?? '';

    _validatePayload(
      username: username,
      fullName: fullName,
      email: email,
      roleId: roleId,
      password: password,
      requirePassword: true,
    );

    final created = await _database.runTx((session) async {
      await _usersRepository.ensureUniqueIdentity(
        session,
        username: username,
        email: email,
      );
      final user = await _usersRepository.create(
        session: session,
        username: username,
        fullName: fullName,
        email: email,
        passwordHash: _passwordService.hashPassword(password),
        roleId: roleId,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'USER_CREATED',
        entityName: 'users',
        entityId: user.id,
        description: 'User account created.',
        newValues: user.toJson(),
      );

      return user;
    });

    return jsonResponse(
      201,
      message: 'User created successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> update(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final username = body['username']?.toString().trim() ?? '';
    final fullName = body['full_name']?.toString().trim() ?? '';
    final email = body['email']?.toString().trim() ?? '';
    final roleId = body['role_id']?.toString().trim() ?? '';
    final isActive = body['is_active'] as bool? ?? true;

    _validatePayload(
      username: username,
      fullName: fullName,
      email: email,
      roleId: roleId,
      password: '',
      requirePassword: false,
    );

    final updated = await _database.runTx((session) async {
      final current = await _usersRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'User not found.',
          statusCode: 404,
          code: 'USER_NOT_FOUND',
        );
      }
      await _usersRepository.ensureUniqueIdentity(
        session,
        username: username,
        email: email,
        ignoreId: id,
      );
      final user = await _usersRepository.update(
        session: session,
        id: id,
        username: username,
        fullName: fullName,
        email: email,
        roleId: roleId,
        isActive: isActive,
      );

      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'USER_UPDATED',
        entityName: 'users',
        entityId: id,
        description: 'User account updated.',
        oldValues: current.toJson(),
        newValues: user.toJson(),
      );
      return user;
    });

    return jsonResponse(
      200,
      message: 'User updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> setStatus(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final isActive = body['is_active'] as bool?;
    if (isActive == null) {
      throw const AppException(
        message: 'Status value is required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final updated = await _database.runTx((session) async {
      final current = await _usersRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'User not found.',
          statusCode: 404,
          code: 'USER_NOT_FOUND',
        );
      }
      final user = await _usersRepository.setStatus(
        session: session,
        id: id,
        isActive: isActive,
      );
      await _auditService.log(
        session: session,
        actor: requestUser,
        action: isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
        entityName: 'users',
        entityId: id,
        description: 'User status changed.',
        oldValues: current.toJson(),
        newValues: user.toJson(),
      );
      return user;
    });

    return jsonResponse(
      200,
      message: 'User status updated successfully.',
      data: updated.toJson(),
    );
  }

  Future<Response> updatePassword(Request request, String id) async {
    final body = await HttpService.parseJsonBody(request);
    final requestUser = _requestUser(request);
    final password = body['password']?.toString() ?? '';
    if (password.length < 8) {
      throw const AppException(
        message: 'Password must be at least 8 characters.',
        statusCode: 422,
        code: 'WEAK_PASSWORD',
      );
    }

    await _database.runTx((session) async {
      final current = await _usersRepository.findById(session, id);
      if (current == null) {
        throw const AppException(
          message: 'User not found.',
          statusCode: 404,
          code: 'USER_NOT_FOUND',
        );
      }
      await _usersRepository.updatePassword(
        session: session,
        id: id,
        passwordHash: _passwordService.hashPassword(password),
      );
      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'USER_PASSWORD_RESET',
        entityName: 'users',
        entityId: id,
        description: 'User password reset by administrator.',
      );
    });

    return jsonResponse(200, message: 'Password updated successfully.');
  }

  void _validatePayload({
    required String username,
    required String fullName,
    required String email,
    required String roleId,
    required String password,
    required bool requirePassword,
  }) {
    if (username.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        roleId.isEmpty) {
      throw const AppException(
        message: 'Username, full name, email, and role are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }
    if (!email.contains('@')) {
      throw const AppException(
        message: 'Email address is invalid.',
        statusCode: 422,
        code: 'INVALID_EMAIL',
      );
    }
    if (requirePassword && password.length < 8) {
      throw const AppException(
        message: 'Password must be at least 8 characters.',
        statusCode: 422,
        code: 'WEAK_PASSWORD',
      );
    }
  }

  RequestUser _requestUser(Request request) {
    final requestUser = request.context[requestUserContextKey] as RequestUser?;
    if (requestUser == null) {
      throw const AppException(
        message: 'Authentication context is missing.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }
    return requestUser;
  }
}
