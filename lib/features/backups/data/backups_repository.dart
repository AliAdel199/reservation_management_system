import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/database_backup_item.dart';

class BackupsRepository {
  const BackupsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DatabaseBackupItem>> fetchBackups() async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/backups',
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة النسخ الاحتياطية.',
          code: 'INVALID_BACKUPS_RESPONSE',
        );
      }

      final items = payload['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map>()
          .map(
            (item) =>
                DatabaseBackupItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<DatabaseBackupItem> createBackup() async {
    try {
      final response = await _apiClient.instance.post<Map<String, dynamic>>(
        '/backups',
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر إنشاء النسخة الاحتياطية.',
          code: 'INVALID_BACKUP_RESPONSE',
        );
      }
      return DatabaseBackupItem.fromJson(payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> restoreBackup(String fileName) async {
    try {
      await _apiClient.instance.post(
        '/backups/restore',
        data: {'file_name': fileName},
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
