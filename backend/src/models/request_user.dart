class RequestUser {
  const RequestUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.roleCode,
    required this.roleName,
  });

  final String id;
  final String username;
  final String fullName;
  final String roleCode;
  final String roleName;

  factory RequestUser.fromClaims(Map<String, dynamic> claims) {
    return RequestUser(
      id: claims['sub'].toString(),
      username: claims['username'].toString(),
      fullName: claims['full_name'].toString(),
      roleCode: claims['role_code'].toString(),
      roleName: claims['role_name'].toString(),
    );
  }
}
