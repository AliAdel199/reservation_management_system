import 'package:shelf/shelf.dart';

import '../services/api_response.dart';
import '../services/license_service.dart';

class LicenseController {
  const LicenseController({required LicenseService licenseService})
    : _licenseService = licenseService;

  final LicenseService _licenseService;

  Future<Response> status(Request request) async {
    final status = await _licenseService.checkStatus();

    return jsonResponse(
      status.valid ? 200 : 403,
      message: status.message,
      code: status.code,
      data: status.toJson(),
    );
  }
}
