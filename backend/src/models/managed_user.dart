class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String roleId;
  final String roleCode;
  final String roleName;
  final bool isActive;
  final String createdAt;

  factory ManagedUser.fromRow(Map<String, dynamic> row) {
    return ManagedUser(
      id: row['id'].toString(),
      username: row['username'].toString(),
      fullName: row['full_name'].toString(),
      email: row['email'].toString(),
      roleId: row['role_id'].toString(),
      roleCode: row['role_code'].toString(),
      roleName: row['role_name'].toString(),
      isActive: row['is_active'] as bool? ?? false,
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role_id': roleId,
      'role_code': roleCode,
      'role_name': roleName,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

class UserRole {
  const UserRole({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  factory UserRole.fromRow(Map<String, dynamic> row) {
    return UserRole(
      id: row['id'].toString(),
      code: row['code'].toString(),
      name: row['name'].toString(),
      description: row['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'code': code, 'name': name, 'description': description};
  }
}
