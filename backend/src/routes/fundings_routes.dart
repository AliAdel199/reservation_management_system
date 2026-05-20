import 'package:shelf_router/shelf_router.dart';

import '../controllers/fundings_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerFundingsRoutes(
  Router router,
  FundingsController controller,
  JwtService jwtService,
) {
  router.get('/api/fundings', protectedRoute(jwtService, controller.list));
  router.post(
    '/api/fundings',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.modifyRecords,
    ),
  );
  router.put(
    '/api/fundings/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
}
