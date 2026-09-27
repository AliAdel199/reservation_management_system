import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../config/app_config.dart';

class DatabaseService {
  DatabaseService({required AppConfig config, required Logger logger})
    : _config = config,
      _logger = logger;

  static const _defaultMaxConnections = 10;

  final AppConfig _config;
  final Logger _logger;
  Pool<void>? _pool;

  // تعليق عربي: نستخدم Pool بدل اتصال واحد مشترك، فكل طلب/معاملة يأخذ اتصالاً مستقلاً،
  // والاتصالات المنقطعة تُستبدل تلقائياً دون أن تُقطع معاملة طلب آخر في منتصفها.
  Pool<void> get connection {
    final currentPool = _pool;
    if (currentPool == null) {
      throw StateError('Database pool has not been initialized.');
    }

    return currentPool;
  }

  Future<void> connect() async {
    await _pool?.close().catchError((Object error, StackTrace stackTrace) {
      _logger.warning(
        'Failed to close previous database pool before reconnecting.',
        error,
        stackTrace,
      );
    });
    _pool = Pool.withUrl(_poolUrl(_config.databaseUrl));
    // تعليق عربي: الـ Pool لا يفتح اتصالاً حتى أول استعلام؛ نفحص الآن ليفشل التشغيل مبكراً.
    await _pool!.execute('SELECT 1');
    _logger.info('Database connection pool established.');
  }

  Future<void> ensureConnected() async {
    if (_pool == null) {
      await connect();
      return;
    }

    await connection.execute('SELECT 1');
  }

  Future<void> close() async {
    await _pool?.close();
    _pool = null;
    _logger.info('Database connection pool closed.');
  }

  Future<T> runTx<T>(Future<T> Function(TxSession session) action) {
    return connection.runTx(action);
  }

  static String _poolUrl(String databaseUrl) {
    final uri = Uri.parse(databaseUrl);
    if (uri.queryParameters.containsKey('max_connection_count')) {
      return databaseUrl;
    }

    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'max_connection_count': '$_defaultMaxConnections',
          },
        )
        .toString();
  }
}
