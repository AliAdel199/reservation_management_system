import 'package:shelf_router/shelf_router.dart';

import '../controllers/institution_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerInstitutionRoutes(
  Router router,
  InstitutionController controller,
  JwtService jwtService,
) {
  router.get('/api/institution', protectedRoute(jwtService, controller.get));
  router.put(
    '/api/institution',
    protectedRoute(
      jwtService,
      controller.update,
      permission: PermissionCodes.manageSettings,
    ),
  );
}
