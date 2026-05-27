import 'package:shelf_router/shelf_router.dart';

import '../controllers/programs_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerProgramsRoutes(
  Router router,
  ProgramsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/programs',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.programsView,
    ),
  );
  router.post(
    '/api/programs',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.programsAdd,
    ),
  );
  router.put(
    '/api/programs/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.programsEdit,
    )(request),
  );
  router.delete(
    '/api/programs/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.programsDelete,
    )(request),
  );
}
