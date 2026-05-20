import 'package:logging/logging.dart';

Logger configureLogging() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen((record) {
    // تعليق عربي: نوحد شكل السجل ليسهل تتبع الأخطاء والأحداث التشغيلية.
    final message =
        '[${record.time.toIso8601String()}] [${record.level.name}] ${record.loggerName}: ${record.message}';
    print(message);
    if (record.error != null) {
      print(record.error);
    }
    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  });

  return Logger('reservation_api');
}
