class ManagedUserItem {
  const ManagedUserItem({
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

  factory ManagedUserItem.fromJson(Map<String, dynamic> json) {
    return ManagedUserItem(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleId: json['role_id']?.toString() ?? '',
      roleCode: json['role_code']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class UserRoleItem {
  const UserRoleItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  factory UserRoleItem.fromJson(Map<String, dynamic> json) {
    return UserRoleItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
