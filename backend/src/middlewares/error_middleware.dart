import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';
import '../services/api_response.dart';

Middleware errorMiddleware(Logger logger) {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } on AppException catch (exception, stackTrace) {
        logger.warning(exception.message, exception, stackTrace);
        return jsonResponse(
          exception.statusCode,
          message: exception.message,
          code: exception.code,
          details: exception.details,
        );
      } catch (exception, stackTrace) {
        logger.severe('Unhandled server exception.', exception, stackTrace);
        return jsonResponse(
          500,
          message: 'حدث خطأ غير متوقع في الخادم. يرجى المحاولة مرة أخرى.',
          code: 'INTERNAL_SERVER_ERROR',
        );
      }
    };
  };
}
