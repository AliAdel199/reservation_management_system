import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';

class HttpService {
  const HttpService._();

  static Future<Map<String, dynamic>> parseJsonBody(Request request) async {
    final body = await request.readAsString();
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AppException(
        message: 'The request body must be a JSON object.',
        statusCode: 400,
        code: 'INVALID_JSON_BODY',
      );
    }

    return decoded;
  }
}
