import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import 'database_service.dart';

class MigrationFile {
  const MigrationFile({required this.version, required this.sql});

  /// اسم الملف بدون .sql، مثل 018_immutable_audit_logs.
  final String version;
  final String sql;

  String get checksum => sha256.convert(utf8.encode(sql)).toString();
}

class MigrationStatus {
  const MigrationStatus({required this.applied, required this.pending});

  final List<String> applied;
  final List<MigrationFile> pending;
}

// تعليق عربي: يطبق ملفات database/migrations الجديدة بالترتيب ويسجلها في schema_migrations.
// كل ملف في معاملة مستقلة: إما يُطبق كاملاً أو لا يُطبق، ولا يتوقف الخادم على قاعدة نصف محدثة.
class MigrationRunner {
  MigrationRunner({
    required DatabaseService database,
    required String directory,
    required Logger logger,
  }) : _database = database,
       _directory = directory,
       _logger = logger;

  /// قواعد العملاء المنشأة قبل وجود schema_migrations جاءت من ملف التثبيت الذي
  /// يشمل كل الملفات حتى هذا الإصدار، فنعتبرها مطبقة دون إعادة تنفيذها.
  static const baselineVersion = '017_deduplicate_roles';

  // تعليق عربي: رقم ثابت لقفل pg_advisory يمنع نسختين من الخادم من الترحيل معاً.
  static const _lockKey = 7294036118;

  final DatabaseService _database;
  final String _directory;
  final Logger _logger;

  List<MigrationFile> loadFiles() {
    final directory = Directory(_directory);
    if (!directory.existsSync()) {
      throw StateError(
        'Migrations directory was not found: ${directory.absolute.path}. '
        'Set MIGRATIONS_DIR or copy database/migrations next to the API.',
      );
    }

    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.sql'))
            .toList()
          ..sort((a, b) => _name(a).compareTo(_name(b)));

    return files
        .map(
          (file) => MigrationFile(
            version: _name(file).replaceAll(RegExp(r'\.sql$'), ''),
            sql: file.readAsStringSync(),
          ),
        )
        .toList();
  }

  Future<MigrationStatus> status() async {
    final files = loadFiles();
    await _ensureTable();
    await _baselineExistingDatabase(files);
    final applied = await _appliedVersions();
    await _warnOnChangedFiles(files);
    return MigrationStatus(
      applied: applied.keys.toList()..sort(),
      pending: files
          .where((file) => !applied.containsKey(file.version))
          .toList(),
    );
  }

  /// يطبق الملفات المعلقة ويعيد أسماءها.
  Future<List<String>> apply(List<MigrationFile> pending) async {
    final appliedNow = <String>[];
    for (final migration in pending) {
      final applied = await _database.runTx((session) async {
        await session.execute('SELECT pg_advisory_xact_lock($_lockKey)');
        final exists = await session.execute(
          Sql.named('SELECT 1 FROM schema_migrations WHERE version = @version'),
          parameters: {'version': migration.version},
        );
        if (exists.isNotEmpty) return false;

        _logger.info('Applying migration ${migration.version}...');
        // تعليق عربي: الوضع البسيط يسمح بتنفيذ ملف يحتوي عدة أوامر SQL.
        await session.execute(migration.sql, queryMode: QueryMode.simple);
        await session.execute(
          Sql.named('''
            INSERT INTO schema_migrations (version, checksum)
            VALUES (@version, @checksum)
          '''),
          parameters: {
            'version': migration.version,
            'checksum': migration.checksum,
          },
        );
        return true;
      });
      if (applied) appliedNow.add(migration.version);
    }
    return appliedNow;
  }

  Future<void> _ensureTable() async {
    await _database.connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(200) PRIMARY KEY,
        checksum VARCHAR(64) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');
  }

  Future<void> _baselineExistingDatabase(List<MigrationFile> files) async {
    await _database.runTx((session) async {
      await session.execute('SELECT pg_advisory_xact_lock($_lockKey)');
      final recorded = await session.execute(
        'SELECT 1 FROM schema_migrations LIMIT 1',
      );
      if (recorded.isNotEmpty) return;

      final state = await session.execute('''
        SELECT
          to_regclass('public.users') IS NOT NULL,
          to_regclass('public.document_attachments') IS NOT NULL
      ''');
      final hasSchema = state.first[0] as bool;
      final hasBaselineSchema = state.first[1] as bool;

      if (!hasSchema) {
        throw StateError(
          'Database is empty. Run deploy/sql/001_customer_database_setup.sql first.',
        );
      }
      if (!hasBaselineSchema) {
        // تعليق عربي: قاعدة أقدم من الإصدار 016؛ لا نخمن ما طُبق عليها.
        throw StateError(
          'Database schema predates migration 016 and has no schema_migrations '
          'history. Upgrade it manually before starting the API.',
        );
      }

      final baseline = files.where(
        (file) => file.version.compareTo(baselineVersion) <= 0,
      );
      for (final file in baseline) {
        await session.execute(
          Sql.named('''
            INSERT INTO schema_migrations (version, checksum)
            VALUES (@version, 'baseline')
            ON CONFLICT (version) DO NOTHING
          '''),
          parameters: {'version': file.version},
        );
      }
      _logger.info(
        'Existing database recorded at migration baseline $baselineVersion.',
      );
    });
  }

  Future<Map<String, String>> _appliedVersions() async {
    final result = await _database.connection.execute(
      'SELECT version, checksum FROM schema_migrations',
    );
    return {for (final row in result) row[0].toString(): row[1].toString()};
  }

  Future<void> _warnOnChangedFiles(List<MigrationFile> files) async {
    final applied = await _appliedVersions();
    for (final file in files) {
      final checksum = applied[file.version];
      if (checksum == null || checksum == 'baseline' || checksum == 'setup') {
        continue;
      }
      if (checksum != file.checksum) {
        _logger.warning(
          'Migration ${file.version} was edited after being applied. '
          'Add a new migration instead of changing an applied one.',
        );
      }
    }
  }

  static String _name(File file) => file.uri.pathSegments.last;
}
