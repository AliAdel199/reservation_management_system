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

  factory DatabaseBackupItem.fromJson(Map<String, dynamic> json) {
    return DatabaseBackupItem(
      fileName: json['file_name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
