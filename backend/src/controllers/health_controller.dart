import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../services/api_response.dart';

class HealthController {
  const HealthController({required DatabaseService database})
    : _database = database;

  final DatabaseService _database;

  Future<Response> status(Request request) async {
    try {
      await _database.ensureConnected();
    } catch (error) {
      return jsonResponse(
        503,
        message: 'Service is running, but database is unavailable.',
        code: 'DATABASE_UNAVAILABLE',
        data: {
          'status': 'degraded',
          'service': 'reservation_management_api',
          'database': 'unavailable',
        },
      );
    }

    return jsonResponse(
      200,
      message: 'Service is healthy.',
      data: {
        'status': 'ok',
        'service': 'reservation_management_api',
        'database': 'ok',
      },
    );
  }
}
