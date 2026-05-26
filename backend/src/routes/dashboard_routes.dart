import 'package:shelf_router/shelf_router.dart';

import '../controllers/dashboard_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerDashboardRoutes(
  Router router,
  DashboardController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/dashboard/summary',
    protectedRoute(jwtService, controller.summary),
  );
  router.get(
    '/api/dashboard/alerts',
    protectedRoute(jwtService, controller.alerts),
  );
  router.get(
    '/api/dashboard/level-three-sections',
    protectedRoute(jwtService, controller.sectionCards),
  );
  router.get(
    '/api/dashboard/section-cards',
    protectedRoute(jwtService, controller.sectionCards),
  );
  router.get(
    '/api/dashboard/analytics',
    protectedRoute(jwtService, controller.analytics),
  );
}
