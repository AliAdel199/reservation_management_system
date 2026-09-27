import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/auth_repository.dart';
import '../services/jwt_service.dart';
import 'request_context_keys.dart';

// تعليق عربي: التوكن يبقى صالحاً لساعات، لذلك لا نعتمد على الصلاحيات المخزنة فيه.
// مع كل طلب نقرأ المستخدم من القاعدة: تعطيل الحساب أو سحب صلاحية يسري فوراً.
// التحقق من صحة التوكن نفسه والرد بأخطائه يبقى من مسؤولية authMiddleware في المسارات المحمية.
Middleware sessionUserMiddleware({
  required JwtService jwtService,
  required DatabaseService database,
  required AuthRepository authRepository,
}) {
  return (innerHandler) {
    return (request) async {
      final authorizationHeader = request.headers['authorization'];
      if (authorizationHeader == null ||
          !authorizationHeader.startsWith('Bearer ')) {
        return innerHandler(request);
      }

      final RequestUser tokenUser;
      try {
        tokenUser = jwtService.verifyToken(
          authorizationHeader.replaceFirst('Bearer ', '').trim(),
        );
      } on JWTException {
        return innerHandler(request);
      }

      final user = await authRepository.findById(
        database.connection,
        tokenUser.id,
      );
      if (user == null || !user.isActive) {
        throw const AppException(
          message: 'تم تعطيل حسابك أو حذفه. يرجى مراجعة مدير النظام.',
          statusCode: 401,
          code: 'ACCOUNT_DISABLED',
        );
      }

      final currentUser = RequestUser(
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        roleCode: user.roleCode,
        roleName: user.roleName,
        permissions: user.permissions,
      );
      return innerHandler(
        request.change(
          context: {...request.context, requestUserContextKey: currentUser},
        ),
      );
    };
  };
}
