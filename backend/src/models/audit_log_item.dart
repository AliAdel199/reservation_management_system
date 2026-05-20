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

  factory AuditLogItem.fromRow(Map<String, dynamic> row) {
    return AuditLogItem(
      id: row['id'].toString(),
      action: row['action'].toString(),
      entityType:
          row['entity_type']?.toString() ?? row['entity_name'].toString(),
      entityId: row['entity_id']?.toString(),
      description: row['description']?.toString(),
      username: row['username']?.toString(),
      fullName: row['full_name']?.toString(),
      ipAddress: row['ip_address']?.toString(),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'username': username,
      'full_name': fullName,
      'ip_address': ipAddress,
      'created_at': createdAt,
    };
  }
}
