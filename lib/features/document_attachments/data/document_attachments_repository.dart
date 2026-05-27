import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/document_attachment_item.dart';

class DocumentAttachmentsRepository {
  const DocumentAttachmentsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DocumentAttachmentItem>> fetch({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/document-attachments',
        queryParameters: {'entity_type': entityType, 'entity_id': entityId},
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة مرفقات المستندات من الخادم.',
          code: 'INVALID_ATTACHMENTS_RESPONSE',
        );
      }

      final items = payload['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map>()
          .map(
            (item) => DocumentAttachmentItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> upload({
    required String entityType,
    required String entityId,
    required PlatformFile file,
    String? notes,
  }) async {
    try {
      final bytes = await _readFileBytes(file);
      await _apiClient.instance.post(
        '/document-attachments',
        data: {
          'entity_type': entityType,
          'entity_id': entityId,
          'file_name': file.name,
          'content_type': _contentType(file.name),
          'content_base64': base64Encode(bytes),
          'notes': notes,
        },
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<int>> download(String id) async {
    try {
      final response = await _apiClient.instance.get<List<int>>(
        '/document-attachments/$id/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.instance.delete('/document-attachments/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<List<int>> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const AppException(
        message: 'تعذر قراءة الملف المختار.',
        code: 'ATTACHMENT_FILE_READ_FAILED',
      );
    }
    return File(path).readAsBytes();
  }

  String _contentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }
}
