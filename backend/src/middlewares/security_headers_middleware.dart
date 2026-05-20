import 'package:shelf/shelf.dart';

Middleware securityHeadersMiddleware() {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'x-content-type-options': 'nosniff',
          'x-frame-options': 'DENY',
          'cache-control': 'no-store',
        },
      );
    };
  };
}
