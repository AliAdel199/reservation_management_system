import 'dart:io';

import '../config/app_config.dart';
import '../models/app_exception.dart';

class DatabaseBackupItem {
  const DatabaseBackupItem({
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String fileName;
  final String path;
  final int sizeBytes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'path': path,
      'size_bytes': sizeBytes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class DatabaseBackupService {
  const DatabaseBackupService(this._config);

  final AppConfig _config;

  Directory get _backupDirectory {
    final configured = _config.backupDirectory.trim();
    if (configured.isEmpty) {
      return Directory('backups');
    }
    return Directory(configured);
  }

  Future<List<DatabaseBackupItem>> listBackups() async {
    final directory = await _ensureBackupDirectory();
    final items = <DatabaseBackupItem>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.dump')) {
        continue;
      }

      final stat = await entity.stat();
      items.add(
        DatabaseBackupItem(
          fileName: _fileName(entity.path),
          path: entity.path,
          sizeBytes: stat.size,
          createdAt: stat.modified,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<DatabaseBackupItem> createBackup() async {
    final directory = await _ensureBackupDirectory();
    final fileName = 'reservation_backup_${_timestamp()}.dump';
    final file = File(_join(directory.path, fileName));

    final result = await Process.run(_config.pgDumpPath, [
      '--format=custom',
      '--no-owner',
      '--no-privileges',
      '--file',
      file.path,
      _config.databaseUrl,
    ], runInShell: false);

    if (result.exitCode != 0) {
      await _deleteFileIfExists(file);
      throw AppException(
        message:
            'Database backup failed. Make sure pg_dump is installed and PG_DUMP_PATH is correct.',
        statusCode: 500,
        code: 'BACKUP_FAILED',
        details: {
          'stderr': result.stderr.toString(),
          'stdout': result.stdout.toString(),
        },
      );
    }

    await _deleteExpiredBackups();
    final stat = await file.stat();
    return DatabaseBackupItem(
      fileName: fileName,
      path: file.path,
      sizeBytes: stat.size,
      createdAt: stat.modified,
    );
  }

  Future<void> restoreBackup(String fileName) async {
    _validateBackupFileName(fileName);
    final directory = await _ensureBackupDirectory();
    final file = File(_join(directory.path, fileName));
    if (!await file.exists()) {
      throw const AppException(
        message: 'Backup file was not found.',
        statusCode: 404,
        code: 'BACKUP_NOT_FOUND',
      );
    }

    final result = await Process.run(_config.pgRestorePath, [
      '--clean',
      '--if-exists',
      '--no-owner',
      '--no-privileges',
      '--dbname',
      _config.databaseUrl,
      file.path,
    ], runInShell: false);

    if (result.exitCode != 0) {
      throw AppException(
        message:
            'Database restore failed. Make sure pg_restore is installed and PG_RESTORE_PATH is correct.',
        statusCode: 500,
        code: 'RESTORE_FAILED',
        details: {
          'stderr': result.stderr.toString(),
          'stdout': result.stdout.toString(),
        },
      );
    }
  }

  Future<Directory> _ensureBackupDirectory() async {
    final directory = _backupDirectory;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _deleteExpiredBackups() async {
    final days = _config.backupRetentionDays;
    if (days <= 0) return;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    for (final item in await listBackups()) {
      if (item.createdAt.isBefore(cutoff)) {
        await _deleteFileIfExists(File(item.path));
      }
    }
  }

  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only; the caller should not fail because cleanup failed.
    }
  }

  void _validateBackupFileName(String value) {
    final fileName = value.trim();
    final valid = RegExp(r'^[A-Za-z0-9_.-]+\.dump$').hasMatch(fileName);
    if (!valid || fileName.contains('/') || fileName.contains(r'\')) {
      throw const AppException(
        message: 'Backup file name is invalid.',
        statusCode: 422,
        code: 'INVALID_BACKUP_FILE',
      );
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _join(String first, String second) {
    final separator = Platform.pathSeparator;
    if (first.endsWith(separator)) return '$first$second';
    return '$first$separator$second';
  }

  String _fileName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }
}
