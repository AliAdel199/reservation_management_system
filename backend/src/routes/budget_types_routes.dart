import 'package:shelf_router/shelf_router.dart';

import '../controllers/budget_types_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerBudgetTypesRoutes(
  Router router,
  BudgetTypesController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/budget-types',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.budgetTypesView,
    ),
  );
  router.post(
    '/api/budget-types',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.budgetTypesAdd,
    ),
  );
  router.put(
    '/api/budget-types/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.budgetTypesEdit,
    )(request),
  );
  router.delete(
    '/api/budget-types/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.budgetTypesDelete,
    )(request),
  );
}
