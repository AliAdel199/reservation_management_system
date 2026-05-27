import 'package:postgres/postgres.dart';

import '../models/document_attachment.dart';

class DocumentAttachmentsRepository {
  const DocumentAttachmentsRepository();

  Future<bool> ownerExists(
    Session session, {
    required String entityType,
    required String entityId,
  }) async {
    final table = switch (entityType) {
      'reservation' => 'reservations',
      'expense' => 'expenses',
      _ => null,
    };
    if (table == null) {
      return false;
    }

    final result = await session.execute(
      Sql.named('''
        SELECT 1
        FROM $table
        WHERE id = @entity_id
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'entity_id': entityId},
    );
    return result.isNotEmpty;
  }

  Future<List<DocumentAttachment>> list(
    Session session, {
    required String entityType,
    required String entityId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          id,
          entity_type,
          entity_id,
          original_file_name,
          stored_file_name,
          content_type,
          file_size,
          storage_path,
          notes,
          uploaded_by,
          created_at
        FROM document_attachments
        WHERE entity_type = @entity_type
          AND entity_id = @entity_id
          AND deleted_at IS NULL
        ORDER BY created_at DESC
      '''),
      parameters: {'entity_type': entityType, 'entity_id': entityId},
    );
    return result
        .map((row) => DocumentAttachment.fromRow(row.toColumnMap()))
        .toList();
  }

  Future<DocumentAttachment?> findById(Session session, String id) async {
    final result = await session.execute(
      Sql.named('''
        SELECT
          id,
          entity_type,
          entity_id,
          original_file_name,
          stored_file_name,
          content_type,
          file_size,
          storage_path,
          notes,
          uploaded_by,
          created_at
        FROM document_attachments
        WHERE id = @id
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'id': id},
    );
    return result.isEmpty
        ? null
        : DocumentAttachment.fromRow(result.first.toColumnMap());
  }

  Future<DocumentAttachment> create({
    required Session session,
    required String entityType,
    required String entityId,
    required String originalFileName,
    required String storedFileName,
    required String contentType,
    required int fileSize,
    required String storagePath,
    required String? notes,
    required String uploadedBy,
  }) async {
    final result = await session.execute(
      Sql.named('''
        INSERT INTO document_attachments (
          entity_type,
          entity_id,
          original_file_name,
          stored_file_name,
          content_type,
          file_size,
          storage_path,
          notes,
          uploaded_by
        )
        VALUES (
          @entity_type,
          @entity_id,
          @original_file_name,
          @stored_file_name,
          @content_type,
          @file_size,
          @storage_path,
          @notes,
          @uploaded_by
        )
        RETURNING
          id,
          entity_type,
          entity_id,
          original_file_name,
          stored_file_name,
          content_type,
          file_size,
          storage_path,
          notes,
          uploaded_by,
          created_at
      '''),
      parameters: {
        'entity_type': entityType,
        'entity_id': entityId,
        'original_file_name': originalFileName,
        'stored_file_name': storedFileName,
        'content_type': contentType,
        'file_size': fileSize,
        'storage_path': storagePath,
        'notes': notes,
        'uploaded_by': uploadedBy,
      },
    );
    return DocumentAttachment.fromRow(result.first.toColumnMap());
  }

  Future<void> softDelete({
    required Session session,
    required String id,
    required String deletedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE document_attachments
        SET deleted_at = NOW(),
            deleted_by = @deleted_by
        WHERE id = @id
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'deleted_by': deletedBy},
    );
  }
}
