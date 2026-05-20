import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(
  int statusCode, {
  required String message,
  String? code,
  Map<String, dynamic>? data,
  Map<String, dynamic>? details,
}) {
  final payload = <String, dynamic>{
    'success': statusCode >= 200 && statusCode < 300,
    'message': message,
    'code': code,
    'data': data,
    'details': details,
  }..removeWhere((key, value) => value == null);

  return Response(
    statusCode,
    body: jsonEncode(payload),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
