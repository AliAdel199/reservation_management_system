import 'package:shelf_router/shelf_router.dart';

import '../controllers/backups_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerBackupsRoutes(
  Router router,
  BackupsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/backups',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.manageBackups,
    ),
  );

  router.post(
    '/api/backups',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.manageBackups,
    ),
  );

  router.post(
    '/api/backups/restore',
    protectedRoute(
      jwtService,
      controller.restore,
      permission: PermissionCodes.manageBackups,
    ),
  );
}
