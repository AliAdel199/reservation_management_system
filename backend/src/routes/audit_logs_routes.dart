import 'package:shelf_router/shelf_router.dart';

import '../controllers/audit_logs_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerAuditLogsRoutes(
  Router router,
  AuditLogsController controller,
  JwtService jwtService,
) {
  router.get('/api/audit-logs', protectedRoute(jwtService, controller.list));
}
