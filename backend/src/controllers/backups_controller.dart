import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/database_backup_service.dart';
import '../services/http_service.dart';

class BackupsController {
  const BackupsController({
    required DatabaseService database,
    required DatabaseBackupService backupService,
    required AuditService auditService,
  }) : _database = database,
       _backupService = backupService,
       _auditService = auditService;

  final DatabaseService _database;
  final DatabaseBackupService _backupService;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final backups = await _backupService.listBackups();
    return jsonResponse(
      200,
      message: 'Database backups retrieved successfully.',
      data: {'items': backups.map((item) => item.toJson()).toList()},
    );
  }

  Future<Response> create(Request request) async {
    final requestUser = _requestUser(request);
    final backup = await _backupService.createBackup();

    await _database.runTx((session) async {
      await _auditService.log(
        session: session,
        actor: requestUser,
        action: 'DATABASE_BACKUP_CREATED',
        entityName: 'database_backups',
        description: 'Database backup created.',
        newValues: backup.toJson(),
      );
    });

    return jsonResponse(
      201,
      message: 'Database backup created successfully.',
      data: backup.toJson(),
    );
  }

  Future<Response> restore(Request request) async {
    final body = await HttpService.parseJsonBody(request);
    final fileName = body['file_name']?.toString().trim() ?? '';
    if (fileName.isEmpty) {
      throw const AppException(
        message: 'Backup file name is required.',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
      );
    }

    final requestUser = _requestUser(request);
    await _database.close();
    try {
      await _backupService.restoreBackup(fileName);
    } finally {
      await _database.connect();
    }

    await _database.runTx((session) async {
      await _auditService.log(
        session: session,
        action: 'DATABASE_BACKUP_RESTORED',
        entityName: 'database_backups',
        description: 'Database restored from backup: $fileName.',
        newValues: {
          'file_name': fileName,
          'requested_by': {
            'id': requestUser.id,
            'username': requestUser.username,
            'full_name': requestUser.fullName,
            'role_code': requestUser.roleCode,
            'role_name': requestUser.roleName,
          },
        },
      );
    });

    return jsonResponse(
      200,
      message: 'Database restored successfully.',
      data: {'file_name': fileName},
    );
  }

  RequestUser _requestUser(Request request) {
    final requestUser = request.context[requestUserContextKey] as RequestUser?;
    if (requestUser == null) {
      throw const AppException(
        message: 'Authentication context is missing.',
        statusCode: 401,
        code: 'UNAUTHENTICATED',
      );
    }
    return requestUser;
  }
}
