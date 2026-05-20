class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.description,
    required this.username,
    required this.fullName,
    required this.ipAddress,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  final String? description;
  final String? username;
  final String? fullName;
  final String? ipAddress;
  final String createdAt;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString(),
      description: json['description']?.toString(),
      username: json['username']?.toString(),
      fullName: json['full_name']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
