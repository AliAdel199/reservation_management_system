import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../services/jwt_service.dart';
import 'request_context_keys.dart';

Middleware authMiddleware(JwtService jwtService) {
  return (innerHandler) {
    return (request) async {
      final authorizationHeader = request.headers['authorization'];
      if (authorizationHeader == null ||
          !authorizationHeader.startsWith('Bearer ')) {
        throw const AppException(
          message: 'Authorization token is missing.',
          statusCode: 401,
          code: 'MISSING_TOKEN',
        );
      }

      final token = authorizationHeader.replaceFirst('Bearer ', '').trim();

      try {
        final requestUser = jwtService.verifyToken(token);
        // تعليق عربي: إن كان sessionUserMiddleware قد حمّل المستخدم من القاعدة نستخدم بياناته الحديثة.
        final sessionUser = request.context[requestUserContextKey];
        if (sessionUser is RequestUser && sessionUser.id == requestUser.id) {
          return await innerHandler(request);
        }
        final enrichedRequest = request.change(
          context: {...request.context, requestUserContextKey: requestUser},
        );
        return await innerHandler(enrichedRequest);
      } on JWTExpiredException {
        throw const AppException(
          message: 'Authentication token has expired.',
          statusCode: 401,
          code: 'TOKEN_EXPIRED',
        );
      } on JWTException {
        throw const AppException(
          message: 'Authentication token is invalid.',
          statusCode: 401,
          code: 'INVALID_TOKEN',
        );
      }
    };
  };
}
