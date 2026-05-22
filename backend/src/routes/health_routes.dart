import 'package:shelf_router/shelf_router.dart';

import '../controllers/health_controller.dart';

void registerHealthRoutes(Router router, HealthController controller) {
  router.get('/', controller.status);
  router.get('/health', controller.status);
}
