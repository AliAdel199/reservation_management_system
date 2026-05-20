import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/auth_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/http_service.dart';
import '../services/jwt_service.dart';
import '../services/password_service.dart';

class AuthController {
  const AuthController({
    required DatabaseService database,
    required AuthRepository authRepository,
    required PasswordService passwordService,
    required JwtService jwtService,
    required AuditService auditService,
  }) : _database = database,
       _authRepository = authRepository,
       _passwordService = passwordService,
       _jwtService = jwtService,
       _auditService = auditService;

  final DatabaseService _database;
  final AuthRepository _authRepository;
  final PasswordService _passwordService;
  final JwtService _jwtService;
  final AuditService _auditService;

  Future<Response> login(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final identity = body['identity']?.toString().trim() ?? '';
    final password = body['password']?.toString() ?? '';

    if (identity.isEmpty || password.isEmpty) {
      throw const AppException(
        message: 'Identity and password are required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final result = await _database.runTx((session) async {
      final user = await _authRepository.findByIdentity(session, identity);
      final headers = request.headers;

      if (user == null ||
          !user.isActive ||
          user.passwordHash == null ||
          !_passwordService.verifyPassword(password, user.passwordHash!)) {
        await _auditService.log(
          session: session,
          action: 'LOGIN_FAILED',
          entityName: 'users',
          entityId: user?.id,
          description: 'Failed login attempt.',
          ipAddress: headers['x-forwarded-for'],
          userAgent: headers['user-agent'],
          newValues: {'identity': identity},
        );
        return null;
      }

      final token = _jwtService.generateToken(user);

      await _auditService.log(
        session: session,
        action: 'LOGIN_SUCCESS',
        entityName: 'users',
        entityId: user.id,
        description: 'User logged in successfully.',
        ipAddress: headers['x-forwarded-for'],
        userAgent: headers['user-agent'],
      );

      return {'token': token, 'user': user.toSafeJson()};
    });

    if (result == null) {
      throw const AppException(
        message: 'Invalid username/email or password.',
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
      );
    }

    return jsonResponse(
      200,
      message: 'Login completed successfully.',
      data: result,
    );
  }

  Future<Response> me(Request request) async {
    final requestUser = request.context[requestUserContextKey] as RequestUser?;
    if (requestUser == null) {
      throw const AppException(
        message: 'Authentication context is missing.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }

    final user = await _authRepository.findById(
      _database.connection,
      requestUser.id,
    );

    if (user == null || !user.isActive) {
      throw const AppException(
        message: 'User account is not available.',
        statusCode: 401,
        code: 'USER_NOT_FOUND',
      );
    }

    return jsonResponse(
      200,
      message: 'Current user retrieved successfully.',
      data: {'user': user.toSafeJson()},
    );
  }
}
