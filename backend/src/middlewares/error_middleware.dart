import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';
import '../services/api_response.dart';

const fiscalYearLockedSqlState = 'FYLCK';

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
        // تعليق عربي: الرمز يأتي من triggers قفل السنة المالية (الترحيل 020).
        if (exception is ServerException &&
            exception.code == fiscalYearLockedSqlState) {
          logger.warning(exception.message, exception, stackTrace);
          return jsonResponse(
            409,
            message:
                'السنة المالية مقفلة، فلا يمكن إضافة أو تعديل أو حذف بياناتها. '
                'راجع من يملك صلاحية قفل وفتح السنة المالية.',
            code: 'FISCAL_YEAR_LOCKED',
          );
        }
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
