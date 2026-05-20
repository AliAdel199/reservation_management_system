import 'package:shelf_router/shelf_router.dart';

import '../controllers/budget_sections_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerBudgetSectionsRoutes(
  Router router,
  BudgetSectionsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/budget-sections',
    protectedRoute(jwtService, controller.list),
  );
  router.post(
    '/api/budget-sections',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.modifyRecords,
    ),
  );
  router.put(
    '/api/budget-sections/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.delete(
    '/api/budget-sections/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.deleteRecords,
    )(request),
  );
}
