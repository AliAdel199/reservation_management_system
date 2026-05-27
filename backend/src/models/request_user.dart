class RequestUser {
  const RequestUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCode,
    required this.roleName,
    this.permissions = const [],
  });

  final String id;
  final String username;
  final String fullName;
  final String roleCode;
  final String roleName;
  final List<String> permissions;

  bool get isSuperAdmin {
    final code = roleCode.trim().toUpperCase();
    return code == 'SUPER_ADMIN' || code == 'SUPERADMIN';
  }

  bool hasPermission(String permission) {
    return isSuperAdmin || permissions.contains(permission);
  }

  factory RequestUser.fromClaims(Map<String, dynamic> claims) {
    final rawPermissions = claims['permissions'];
    return RequestUser(
      id: claims['sub'].toString(),
      username: claims['username'].toString(),
      fullName: claims['full_name'].toString(),
      roleCode: claims['role_code'].toString(),
      roleName: claims['role_name'].toString(),
      permissions: rawPermissions is List
          ? rawPermissions.map((item) => item.toString()).toList()
          : const [],
    );
  }
}
