import 'package:shelf_router/shelf_router.dart';

import '../controllers/document_attachments_controller.dart';
import '../middlewares/permission_middleware.dart';
import '../services/jwt_service.dart';

void registerDocumentAttachmentsRoutes(
  Router router,
  DocumentAttachmentsController controller,
  JwtService jwtService,
) {
  router.get(
    '/api/document-attachments',
    protectedRoute(jwtService, controller.list),
  );
  router.post(
    '/api/document-attachments',
    protectedRoute(jwtService, controller.create),
  );
  router.get(
    '/api/document-attachments/<id>/download',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.download(request, request.params['id']!),
    )(request),
  );
  router.delete(
    '/api/document-attachments/<id>',
    (request) => protectedRoute(
      jwtService,
      (request) => controller.delete(request, request.params['id']!),
    )(request),
  );
}
