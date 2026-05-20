import 'package:shelf_router/shelf_router.dart';

import '../controllers/users_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerUsersRoutes(
  Router router,
  UsersController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/users',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.manageUsers,
    ),
  );
  router.get(
    '/api/users/roles',
    protectedRoute(
      jwtService,
      controller.roles,
      permission: PermissionCodes.manageUsers,
    ),
  );
  router.post(
    '/api/users',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.manageUsers,
    ),
  );
  router.put(
    '/api/users/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.manageUsers,
    )(request),
  );
  router.patch(
    '/api/users/<id>/status',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.setStatus(request, request.params['id']!),
      permission: PermissionCodes.manageUsers,
    )(request),
  );
  router.patch(
    '/api/users/<id>/password',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.updatePassword(request, request.params['id']!),
      permission: PermissionCodes.manageUsers,
    )(request),
  );
}
