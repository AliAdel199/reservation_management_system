import 'package:shelf/shelf.dart';

import '../database/database_service.dart';
import '../middlewares/request_context_keys.dart';
import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../repositories/document_attachments_repository.dart';
import '../services/api_response.dart';
import '../services/audit_service.dart';
import '../services/document_storage_service.dart';
import '../services/http_service.dart';

class DocumentAttachmentsController {
  const DocumentAttachmentsController({
    required DatabaseService database,
    required DocumentAttachmentsRepository repository,
    required DocumentStorageService storageService,
    required AuditService auditService,
  }) : _database = database,
       _repository = repository,
       _storageService = storageService,
       _auditService = auditService;

  final DatabaseService _database;
  final DocumentAttachmentsRepository _repository;
  final DocumentStorageService _storageService;
  final AuditService _auditService;

  Future<Response> list(Request request) async {
    final entityType = _normalizeEntityType(
      request.url.queryParameters['entity_type'],
    );
    final entityId = request.url.queryParameters['entity_id']?.trim() ?? '';
    if (entityId.isEmpty) {
      throw const AppException(
        message: 'Entity id is required.',
        statusCode: 422,
        code: 'ENTITY_ID_REQUIRED',
      );
    }

    final items = await _repository.list(
      _database.connection,
      entityType: entityType,
      entityId: entityId,
    );

    return jsonResponse(
      200,
      message: 'Document attachments retrieved successfully.',
      data: {'items': items.map((item) => item.toJson()).toList()},
    );
  }

  Future<Response> create(Request request) async {
    final user = _requestUser(request);
    final body = await HttpService.parseJsonBody(request);
    final entityType = _normalizeEntityType(body['entity_type']?.toString());
    final entityId = body['entity_id']?.toString().trim() ?? '';
    final originalFileName = body['file_name']?.toString().trim() ?? '';
    final contentType = body['content_type']?.toString().trim() ?? '';
    final contentBase64 = body['content_base64']?.toString().trim() ?? '';
    final notes = body['notes']?.toString().trim();

    if (entityId.isEmpty ||
        originalFileName.isEmpty ||
        contentType.isEmpty ||
        contentBase64.isEmpty) {
      throw const AppException(
        message:
            'Entity, file name, content type, and file content are required.',
        statusCode: 422,
        code: 'ATTACHMENT_FIELDS_REQUIRED',
      );
    }

    final created = await _database.runTx((session) async {
      final exists = await _repository.ownerExists(
        session,
        entityType: entityType,
        entityId: entityId,
      );
      if (!exists) {
        throw const AppException(
          message: 'Attachment owner was not found.',
          statusCode: 404,
          code: 'ATTACHMENT_OWNER_NOT_FOUND',
        );
      }

      final stored = await _storageService.save(
        entityType: entityType,
        entityId: entityId,
        originalFileName: originalFileName,
        contentType: contentType,
        base64Content: contentBase64,
      );

      final attachment = await _repository.create(
        session: session,
        entityType: entityType,
        entityId: entityId,
        originalFileName: stored.originalFileName,
        storedFileName: stored.storedFileName,
        contentType: contentType,
        fileSize: stored.fileSize,
        storagePath: stored.storagePath,
        notes: notes?.isEmpty == true ? null : notes,
        uploadedBy: user.id,
      );

      await _auditService.log(
        session: session,
        actor: user,
        action: 'DOCUMENT_ATTACHMENT_CREATED',
        entityName: 'document_attachments',
        entityId: attachment.id,
        description: 'Document attachment uploaded for $entityType $entityId.',
        newValues: attachment.toJson(),
      );

      return attachment;
    });

    return jsonResponse(
      201,
      message: 'Document attachment uploaded successfully.',
      data: created.toJson(),
    );
  }

  Future<Response> download(Request request, String id) async {
    final attachment = await _repository.findById(_database.connection, id);
    if (attachment == null) {
      throw const AppException(
        message: 'Attachment not found.',
        statusCode: 404,
        code: 'ATTACHMENT_NOT_FOUND',
      );
    }

    final bytes = await _storageService.read(attachment);
    return Response.ok(
      bytes,
      headers: {
        'content-type': attachment.contentType,
        'content-disposition':
            'attachment; filename="${attachment.originalFileName}"',
      },
    );
  }

  Future<Response> delete(Request request, String id) async {
    final user = _requestUser(request);
    final deleted = await _database.runTx((session) async {
      final attachment = await _repository.findById(session, id);
      if (attachment == null) {
        throw const AppException(
          message: 'Attachment not found.',
          statusCode: 404,
          code: 'ATTACHMENT_NOT_FOUND',
        );
      }

      await _repository.softDelete(
        session: session,
        id: id,
        deletedBy: user.id,
      );
      await _storageService.deleteFile(attachment);
      await _auditService.log(
        session: session,
        actor: user,
        action: 'DOCUMENT_ATTACHMENT_DELETED',
        entityName: 'document_attachments',
        entityId: attachment.id,
        description: 'Document attachment deleted.',
        oldValues: attachment.toJson(),
      );
      return attachment;
    });

    return jsonResponse(
      200,
      message: 'Document attachment deleted successfully.',
      data: deleted.toJson(),
    );
  }

  String _normalizeEntityType(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized != 'reservation' && normalized != 'expense') {
      throw const AppException(
        message: 'Attachment entity type must be reservation or expense.',
        statusCode: 422,
        code: 'INVALID_ATTACHMENT_ENTITY_TYPE',
      );
    }
    return normalized;
  }

  RequestUser _requestUser(Request request) {
    final user = request.context[requestUserContextKey];
    if (user is RequestUser) {
      return user;
    }
    throw const AppException(
      message: 'Authenticated user context is missing.',
      statusCode: 401,
      code: 'AUTH_CONTEXT_MISSING',
    );
  }
}
