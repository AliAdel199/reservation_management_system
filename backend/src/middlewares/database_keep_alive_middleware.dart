import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../database/database_service.dart';

Middleware databaseKeepAliveMiddleware(DatabaseService database, Logger logger) {
  return (innerHandler) {
    return (request) async {
      if (request.url.path == 'health') {
        return innerHandler(request);
      }

      // تعليق عربي: قبل أي طلب API نتأكد أن اتصال PostgreSQL ما زال صالحاً.
      await database.ensureConnected();
      logger.fine('Database connection verified before request.');
      return innerHandler(request);
    };
  };
}
