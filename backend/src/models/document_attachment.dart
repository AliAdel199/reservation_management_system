class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.originalFileName,
    required this.storedFileName,
    required this.contentType,
    required this.fileSize,
    required this.storagePath,
    required this.notes,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String originalFileName;
  final String storedFileName;
  final String contentType;
  final int fileSize;
  final String storagePath;
  final String? notes;
  final String? uploadedBy;
  final String createdAt;

  factory DocumentAttachment.fromRow(Map<String, dynamic> row) {
    return DocumentAttachment(
      id: row['id'].toString(),
      entityType: row['entity_type'].toString(),
      entityId: row['entity_id'].toString(),
      originalFileName: row['original_file_name'].toString(),
      storedFileName: row['stored_file_name'].toString(),
      contentType: row['content_type'].toString(),
      fileSize: int.tryParse(row['file_size'].toString()) ?? 0,
      storagePath: row['storage_path'].toString(),
      notes: row['notes']?.toString(),
      uploadedBy: row['uploaded_by']?.toString(),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'original_file_name': originalFileName,
      'content_type': contentType,
      'file_size': fileSize,
      'notes': notes,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
    };
  }
}
