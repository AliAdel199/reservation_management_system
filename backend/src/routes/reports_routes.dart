import 'package:shelf_router/shelf_router.dart';

import '../controllers/reports_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerReportsRoutes(
  Router router,
  ReportsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/reports/section-summary',
    protectedRoute(
      jwtService,
      controller.sectionSummary,
      permission: PermissionCodes.reportsViewPage,
    ),
  );
}
