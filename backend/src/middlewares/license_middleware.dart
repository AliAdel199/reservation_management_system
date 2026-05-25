import 'package:shelf/shelf.dart';

import '../services/api_response.dart';
import '../services/license_service.dart';

Middleware licenseMiddleware(LicenseService licenseService) {
  const allowedPaths = {'/', '/health', '/license/status'};

  return (innerHandler) {
    return (request) async {
      if (allowedPaths.contains(
        request.url.path.isEmpty ? '/' : '/${request.url.path}',
      )) {
        return innerHandler(request);
      }

      final status = await licenseService.checkStatus();
      if (!status.enforced || status.valid) {
        return innerHandler(request);
      }

      return jsonResponse(
        403,
        message: status.message,
        code: status.code ?? 'LICENSE_INVALID',
        data: status.toJson(),
      );
    };
  };
}
