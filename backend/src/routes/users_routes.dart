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
      permission: PermissionCodes.usersView,
    ),
  );
  router.get(
    '/api/users/roles',
    protectedRoute(
      jwtService,
      controller.roles,
      permission: PermissionCodes.usersView,
    ),
  );
  router.post(
    '/api/users',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.usersAdd,
    ),
  );
  router.put(
    '/api/users/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.usersEdit,
    )(request),
  );
  router.patch(
    '/api/users/<id>/status',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.setStatus(request, request.params['id']!),
      permission: PermissionCodes.usersEdit,
    )(request),
  );
  router.patch(
    '/api/users/<id>/password',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.updatePassword(request, request.params['id']!),
      permission: PermissionCodes.usersEdit,
    )(request),
  );
}
