import 'package:shelf_router/shelf_router.dart';

import '../controllers/monthly_fundings_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerMonthlyFundingsRoutes(
  Router router,
  MonthlyFundingsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/monthly-fundings',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.fundingsView,
    ),
  );
  router.post(
    '/api/monthly-fundings',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.fundingsAdd,
    ),
  );
  router.put(
    '/api/monthly-fundings/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.fundingsEdit,
    )(request),
  );
  router.delete(
    '/api/monthly-fundings/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.fundingsDelete,
    )(request),
  );
}
