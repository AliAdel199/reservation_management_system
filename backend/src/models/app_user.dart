class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.isActive,
    this.permissions = const [],
    this.passwordHash,
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String roleId;
  final String roleCode;
  final String roleName;
  final bool isActive;
  final List<String> permissions;
  final String? passwordHash;

  factory AppUser.fromRow(
    Map<String, dynamic> row, {
    List<String> permissions = const [],
  }) {
    return AppUser(
      id: row['id'].toString(),
      username: row['username'].toString(),
      fullName: row['full_name'].toString(),
      email: row['email'].toString(),
      roleId: row['role_id'].toString(),
      roleCode: row['role_code'].toString(),
      roleName: row['role_name'].toString(),
      isActive: row['is_active'] as bool,
      permissions: permissions,
      passwordHash: row['password_hash']?.toString(),
    );
  }

  Map<String, dynamic> toSafeJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role_id': roleId,
      'role_code': roleCode,
      'role_name': roleName,
      'is_active': isActive,
      'permissions': permissions,
    };
  }
}
