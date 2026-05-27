class DocumentAttachmentItem {
  const DocumentAttachmentItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.originalFileName,
    required this.contentType,
    required this.fileSize,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String originalFileName;
  final String contentType;
  final int fileSize;
  final String? notes;
  final String createdAt;

  factory DocumentAttachmentItem.fromJson(Map<String, dynamic> json) {
    return DocumentAttachmentItem(
      id: json['id'].toString(),
      entityType: json['entity_type'].toString(),
      entityId: json['entity_id'].toString(),
      originalFileName: json['original_file_name'].toString(),
      contentType: json['content_type'].toString(),
      fileSize: int.tryParse(json['file_size'].toString()) ?? 0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'].toString(),
    );
  }
}
