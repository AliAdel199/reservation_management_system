import 'package:shelf_router/shelf_router.dart';

import '../controllers/fiscal_years_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerFiscalYearsRoutes(
  Router router,
  FiscalYearsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/fiscal-years',
    protectedRoute(
      jwtService,
      controller.list,
      permission: PermissionCodes.fiscalYearsView,
    ),
  );
  router.post(
    '/api/fiscal-years',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.fiscalYearsAdd,
    ),
  );
  router.put(
    '/api/fiscal-years/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.fiscalYearsEdit,
    )(request),
  );
  router.delete(
    '/api/fiscal-years/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.fiscalYearsDelete,
    )(request),
  );
  router.patch(
    '/api/fiscal-years/<id>/activate',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.activate(request, request.params['id']!),
      permission: PermissionCodes.fiscalYearsEdit,
    )(request),
  );
}
