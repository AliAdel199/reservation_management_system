import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../config/app_config.dart';

class DatabaseService {
  DatabaseService({required AppConfig config, required Logger logger})
    : _config = config,
      _logger = logger;

  final AppConfig _config;
  final Logger _logger;
  Connection? _connection;

  Connection get connection {
    final currentConnection = _connection;
    if (currentConnection == null) {
      throw StateError('Database connection has not been initialized.');
    }

    return currentConnection;
  }

  Future<void> connect() async {
    await _connection?.close().catchError((Object error, StackTrace stackTrace) {
      _logger.warning(
        'Failed to close previous database connection before reconnecting.',
        error,
        stackTrace,
      );
    });
    _connection = await Connection.openFromUrl(_config.databaseUrl);
    _logger.info('Database connection established.');
  }

  Future<void> ensureConnected() async {
    final currentConnection = _connection;
    if (currentConnection == null) {
      await connect();
      return;
    }

    try {
      // تعليق عربي: فحص خفيف يحافظ على الاتصال ويكشف الانقطاع مبكراً.
      await currentConnection.execute('SELECT 1');
    } catch (error, stackTrace) {
      _logger.warning(
        'Database connection health check failed. Reconnecting...',
        error,
        stackTrace,
      );
      await connect();
    }
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
    _logger.info('Database connection closed.');
  }

  Future<T> runTx<T>(Future<T> Function(TxSession session) action) async {
    await ensureConnected();
    return connection.runTx(action);
  }
}
