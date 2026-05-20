import 'package:shelf_router/shelf_router.dart';

import '../controllers/reservations_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerReservationsRoutes(
  Router router,
  ReservationsController controller,
  JwtService jwtService,
) {
  router.get('/api/reservations', protectedRoute(jwtService, controller.list));
  router.post(
    '/api/reservations',
    protectedRoute(
      jwtService,
      controller.create,
      permission: PermissionCodes.modifyRecords,
    ),
  );
  router.put(
    '/api/reservations/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.update(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.delete(
    '/api/reservations/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
      permission: PermissionCodes.deleteRecords,
    )(request),
  );
  router.post(
    '/api/reservations/<id>/submit-review',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.submitForReview(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.post(
    '/api/reservations/<id>/approve',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.approve(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.post(
    '/api/reservations/<id>/cancel',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.cancel(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.patch(
    '/api/reservations/<id>/submit',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.submitForReview(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.patch(
    '/api/reservations/<id>/approve',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.approve(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
  router.patch(
    '/api/reservations/<id>/cancel',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.cancel(request, request.params['id']!),
      permission: PermissionCodes.modifyRecords,
    )(request),
  );
}
