@TestOn('vm')
library;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../src/config/app_config.dart';
import '../src/database/database_service.dart';
import '../src/database/migration_runner.dart';
import 'support/test_database.dart';

const _migrationsDir = '../database/migrations';

late DatabaseService _database;
final _logger = Logger('migration-test');

MigrationRunner _runner([String directory = _migrationsDir]) =>
    MigrationRunner(database: _database, directory: directory, logger: _logger);

Future<List<String>> _recordedVersions() async {
  final result = await _database.connection.execute(
    'SELECT version FROM schema_migrations ORDER BY version',
  );
  return result.map((row) => row[0].toString()).toList();
}

void main() {
  setUpAll(() async {
    final config = AppConfig(
      appName: 'test',
      host: 'localhost',
      port: 0,
      databaseUrl: testDatabaseUrl(),
      jwtSecret: 'integration-test-secret-integration-test-secret',
      jwtExpiresInHours: 1,
      defaultAdminUsername: 'x',
      defaultAdminPassword: 'x',
      defaultAdminFullName: 'x',
      defaultAdminEmail: 'x@x.test',
      resetDefaultAdminPassword: false,
      licenseEnforcementEnabled: false,
      licenseFilePath: 'license.json',
      licensePublicKeyPath: 'license_public.pem',
      backupDirectory: 'backups',
      attachmentDirectory: 'attachments',
      pgDumpPath: 'pg_dump',
      pgRestorePath: 'pg_restore',
      backupRetentionDays: 30,
    );
    _database = DatabaseService(config: config, logger: _logger);
    await _database.connect();
  });

  tearDownAll(() => _database.close());

  test(
    'قاعدة عميل قائمة بلا سجل تُعلَّم حتى 017 ثم تُطبق الترحيلات الأحدث فقط',
    () async {
      // تعليق عربي: نحاكي قاعدة عميل أُنشئت قبل وجود جدول schema_migrations.
      await _database.connection.execute(
        'DROP TABLE IF EXISTS schema_migrations',
      );

      final status = await _runner().status();
      expect(status.applied, contains(MigrationRunner.baselineVersion));
      expect(
        status.applied.every(
          (version) => version.compareTo(MigrationRunner.baselineVersion) <= 0,
        ),
        isTrue,
      );
      expect(
        status.pending.map((m) => m.version),
        containsAll(['018_immutable_audit_logs', '019_user_permissions']),
      );

      // تعليق عربي: 018 و019 مطبقان مسبقاً على قاعدة الاختبار؛ إعادة تطبيقهما يجب أن تنجح (idempotent).
      final applied = await _runner().apply(status.pending);
      expect(applied, status.pending.map((m) => m.version).toList());

      final again = await _runner().status();
      expect(again.pending, isEmpty);
    },
  );

  test('ترحيل فاشل يُلغى بالكامل ولا يُسجَّل', () async {
    final directory = await Directory.systemTemp.createTemp('migrations_');
    addTearDown(() => directory.delete(recursive: true));
    for (final file in Directory(_migrationsDir).listSync().whereType<File>()) {
      await file.copy('${directory.path}/${file.uri.pathSegments.last}');
    }
    await File('${directory.path}/999_broken.sql').writeAsString('''
      CREATE TABLE migration_test_partial (id INT);
      SELECT 1 / 0;
    ''');

    final status = await _runner(directory.path).status();
    expect(status.pending.map((m) => m.version), ['999_broken']);
    await expectLater(
      _runner(directory.path).apply(status.pending),
      throwsA(isA<ServerException>()),
    );

    expect(await _recordedVersions(), isNot(contains('999_broken')));
    final table = await _database.connection.execute(
      "SELECT to_regclass('public.migration_test_partial') IS NULL",
    );
    expect(table.first[0], isTrue);
  });

  test('ملف تثبيت العميل يسجل كل ملفات الترحيل', () {
    // تعليق عربي: ملف التثبيت يُجمَّع يدوياً؛ هذا يمنع نسيان تسجيل ترحيل جديد فيه
    // (وإلا أعاد الخادم تطبيقه على قاعدة جديدة).
    final setup = File(
      '../deploy/sql/001_customer_database_setup.sql',
    ).readAsStringSync();
    final missing = _runner()
        .loadFiles()
        .map((m) => m.version)
        .where((version) => !setup.contains("('$version', 'setup')"))
        .toList();
    expect(missing, isEmpty);
  });
}
