class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.roleCode,
    required this.roleName,
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String roleCode;
  final String roleName;

  String get normalizedRoleCode => roleCode.trim().toUpperCase();

  bool get isSuperAdmin =>
      normalizedRoleCode == 'SUPER_ADMIN' || normalizedRoleCode == 'SUPERADMIN';

  bool get canViewRecords =>
      isSuperAdmin ||
      {
        'ADMIN',
        'FINANCE_MANAGER',
        'FINANCIAL_MANAGER',
        'REVIEWER',
        'FINANCIAL_AUDITOR',
        'DATA_ENTRY',
        'VIEWER',
      }.contains(normalizedRoleCode);

  bool get canModifyRecords =>
      isSuperAdmin ||
      {
        'ADMIN',
        'FINANCE_MANAGER',
        'FINANCIAL_MANAGER',
        'REVIEWER',
        'FINANCIAL_AUDITOR',
        'DATA_ENTRY',
      }.contains(normalizedRoleCode);

  bool get canDeleteRecords => isSuperAdmin;

  bool get canManageUsers => isSuperAdmin;

  bool get canManageBackups => isSuperAdmin;

  bool get canUseDataExchange => isSuperAdmin || normalizedRoleCode == 'ADMIN';

  bool get canExportReports =>
      isSuperAdmin ||
      {
        'ADMIN',
        'FINANCE_MANAGER',
        'FINANCIAL_MANAGER',
        'REVIEWER',
        'FINANCIAL_AUDITOR',
        'DATA_ENTRY',
      }.contains(normalizedRoleCode);

  bool get canViewAuditLogs =>
      isSuperAdmin ||
      {
        'ADMIN',
        'FINANCE_MANAGER',
        'FINANCIAL_MANAGER',
        'REVIEWER',
        'FINANCIAL_AUDITOR',
      }.contains(normalizedRoleCode);

  bool get isViewOnly => !canModifyRecords;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role_code': roleCode,
      'role_name': roleName,
    };
  }
}
