import 'package:shelf_router/shelf_router.dart';

import '../controllers/auth_controller.dart';
import '../middlewares/auth_middleware.dart';
import '../services/jwt_service.dart';

void registerAuthRoutes(
  Router router,
  AuthController controller,
  JwtService jwtService,
) {
  router.post('/api/auth/login', controller.login);
  router.get('/api/auth/me', authMiddleware(jwtService)(controller.me));
}
