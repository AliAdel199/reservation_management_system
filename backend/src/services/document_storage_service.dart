import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/app_exception.dart';
import '../models/document_attachment.dart';

class DocumentStorageService {
  DocumentStorageService(this._config);

  static const _uuid = Uuid();
  static const maxFileSizeBytes = 10 * 1024 * 1024;
  static const _allowedExtensions = {'pdf', 'png', 'jpg', 'jpeg'};
  static const _allowedContentTypes = {
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/jpg',
  };

  final AppConfig _config;

  Future<StoredDocument> save({
    required String entityType,
    required String entityId,
    required String originalFileName,
    required String contentType,
    required String base64Content,
  }) async {
    final safeName = _safeFileName(originalFileName);
    final extension = _extensionOf(safeName);
    if (!_allowedExtensions.contains(extension)) {
      throw const AppException(
        message: 'Only PDF, PNG, JPG, and JPEG attachments are allowed.',
        statusCode: 422,
        code: 'ATTACHMENT_TYPE_NOT_ALLOWED',
      );
    }
    if (!_allowedContentTypes.contains(contentType.toLowerCase())) {
      throw const AppException(
        message: 'Attachment content type is not allowed.',
        statusCode: 422,
        code: 'ATTACHMENT_CONTENT_TYPE_NOT_ALLOWED',
      );
    }

    final bytes = _decodeBase64(base64Content);
    if (bytes.isEmpty || bytes.length > maxFileSizeBytes) {
      throw const AppException(
        message: 'Attachment size must be between 1 byte and 10 MB.',
        statusCode: 422,
        code: 'ATTACHMENT_SIZE_INVALID',
      );
    }

    final directory = Directory(
      '${_config.attachmentDirectory}${Platform.pathSeparator}$entityType'
      '${Platform.pathSeparator}$entityId',
    );
    await directory.create(recursive: true);

    final digest = sha256.convert(bytes).toString().substring(0, 16);
    final storedFileName = '${_uuid.v4()}_$digest.$extension';
    final file = File(
      '${directory.path}${Platform.pathSeparator}$storedFileName',
    );
    await file.writeAsBytes(bytes, flush: true);

    return StoredDocument(
      originalFileName: safeName,
      storedFileName: storedFileName,
      storagePath: file.path,
      fileSize: bytes.length,
    );
  }

  Future<List<int>> read(DocumentAttachment attachment) async {
    final file = File(attachment.storagePath);
    if (!await file.exists()) {
      throw const AppException(
        message: 'Attachment file was not found on the server.',
        statusCode: 404,
        code: 'ATTACHMENT_FILE_NOT_FOUND',
      );
    }
    return file.readAsBytes();
  }

  Future<void> deleteFile(DocumentAttachment attachment) async {
    final file = File(attachment.storagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  List<int> _decodeBase64(String content) {
    try {
      final normalized = content.contains(',')
          ? content.substring(content.indexOf(',') + 1)
          : content;
      return base64Decode(normalized);
    } on FormatException {
      throw const AppException(
        message: 'Attachment content must be a valid Base64 string.',
        statusCode: 400,
        code: 'INVALID_ATTACHMENT_BASE64',
      );
    }
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (normalized.isEmpty || !normalized.contains('.')) {
      throw const AppException(
        message: 'Attachment file name is invalid.',
        statusCode: 422,
        code: 'INVALID_ATTACHMENT_FILE_NAME',
      );
    }
    return normalized;
  }

  String _extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) {
      return '';
    }
    return fileName.substring(index + 1).toLowerCase();
  }
}

class StoredDocument {
  const StoredDocument({
    required this.originalFileName,
    required this.storedFileName,
    required this.storagePath,
    required this.fileSize,
  });

  final String originalFileName;
  final String storedFileName;
  final String storagePath;
  final int fileSize;
}
