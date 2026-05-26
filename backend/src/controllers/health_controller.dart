import 'dart:io';

import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../services/api_response.dart';

class HealthController {
  const HealthController({required DatabaseService database})
    : _database = database;

  final DatabaseService _database;

  Future<Response> status(Request request) async {
    final serverDetails = await _serverDetails();
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
          ...serverDetails,
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
        ...serverDetails,
      },
    );
  }

  Future<Map<String, dynamic>> _serverDetails() async {
    final addresses = <String>[];
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            addresses.add(address.address);
          }
        }
      }
    } catch (_) {
      // Network interface lookup is diagnostic only; health should still work.
    }

    return {
      'server_name': Platform.localHostname,
      'server_ips': addresses,
      'server_time': DateTime.now().toIso8601String(),
    };
  }
}
