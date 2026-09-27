// تشغيل يدوي لترحيلات قاعدة البيانات (الخادم يشغلها تلقائياً عند البدء إن كان AUTO_MIGRATE=true).
//   dart run bin/migrate.dart            تطبيق الترحيلات المعلقة، مع نسخة احتياطية قبلها
//   dart run bin/migrate.dart --status   عرض الحالة فقط
// لتعطيل النسخة الاحتياطية: BACKUP_BEFORE_MIGRATE=false في .env
import 'dart:io';

import '../src/config/app_config.dart';
import '../src/config/logger_config.dart';
import '../src/database/database_service.dart';
import '../src/database/migration_runner.dart';
import '../src/main.dart';

Future<void> main(List<String> args) async {
  final config = AppConfig.fromEnvironment();
  final logger = configureLogging();
  final database = DatabaseService(config: config, logger: logger);
  await database.connect();

  try {
    if (args.contains('--status')) {
      final status = await MigrationRunner(
        database: database,
        directory: config.migrationsDirectory,
        logger: logger,
      ).status();
      stdout.writeln('Applied: ${status.applied.length}');
      for (final migration in status.pending) {
        stdout.writeln('Pending: ${migration.version}');
      }
      if (status.pending.isEmpty) stdout.writeln('Up to date.');
      return;
    }

    final applied = await runPendingMigrations(
      config: config,
      database: database,
      logger: logger,
    );
    stdout.writeln(
      applied.isEmpty ? 'Up to date.' : 'Applied: ${applied.join(', ')}',
    );
  } finally {
    await database.close();
  }
}
