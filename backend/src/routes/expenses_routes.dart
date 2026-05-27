import 'package:shelf_router/shelf_router.dart';

import '../controllers/expenses_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerExpensesRoutes(
  Router router,
  ExpensesController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/expenses',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.expensesView,
    ),
  );
  router.post(
    '/api/expenses',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.expensesAdd,
    ),
  );
  router.patch(
    '/api/expenses/<id>/cancel',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.cancel(request, request.params['id']!),
      permission: PermissionCodes.expensesCancel,
    )(request),
  );
}
