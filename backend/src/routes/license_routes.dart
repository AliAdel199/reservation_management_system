import 'package:shelf_router/shelf_router.dart';

import '../controllers/license_controller.dart';

void registerLicenseRoutes(Router router, LicenseController controller) {
  router.get('/license/status', controller.status);
}
