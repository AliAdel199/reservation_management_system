class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.roleCode,
    required this.roleName,
    this.permissions = const [],
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String roleCode;
  final String roleName;
  final List<String> permissions;

  String get normalizedRoleCode => roleCode.trim().toUpperCase();

  bool get isSuperAdmin =>
      normalizedRoleCode == 'SUPER_ADMIN' || normalizedRoleCode == 'SUPERADMIN';

  bool hasPermission(String code) {
    return isSuperAdmin || permissions.contains(code);
  }

  bool get canViewRecords =>
      hasPermission('view_records') ||
      hasPermission('dashboard.view') ||
      hasPermission('reservations.view');

  bool get canModifyRecords =>
      hasPermission('modify_records') ||
      canAddPrograms ||
      canAddBudgetSections ||
      canAddReservations ||
      canAddExpenses;

  bool get canDeleteRecords =>
      hasPermission('delete_records') ||
      canDeletePrograms ||
      canDeleteBudgetSections ||
      canDeleteReservations;

  bool get canManageUsers =>
      hasPermission('manage_users') ||
      hasPermission('users.view') ||
      hasPermission('users.add') ||
      hasPermission('users.edit');

  bool get canManageBackups =>
      hasPermission('manage_backups') ||
      hasPermission('backups.view') ||
      hasPermission('backups.create') ||
      hasPermission('backups.restore');

  bool get canUseDataExchange =>
      hasPermission('data_exchange.view') ||
      hasPermission('data_exchange.import') ||
      hasPermission('data_exchange.export');

  bool get canImportData => hasPermission('data_exchange.import');
  bool get canExportData => hasPermission('data_exchange.export');

  bool get canExportReports =>
      hasPermission('export_reports') || hasPermission('reports.export');

  bool get canPrintReports => hasPermission('reports.print');

  bool get canViewAuditLogs =>
      hasPermission('view_audit_logs') || hasPermission('audit_logs.view');

  bool get canAddPrograms => hasPermission('programs.add');
  bool get canEditPrograms => hasPermission('programs.edit');
  bool get canDeletePrograms => hasPermission('programs.delete');

  bool get canAddBudgetSections => hasPermission('budget_sections.add');
  bool get canEditBudgetSections => hasPermission('budget_sections.edit');
  bool get canDeleteBudgetSections => hasPermission('budget_sections.delete');

  bool get canAddReservations => hasPermission('reservations.add');
  bool get canEditReservations => hasPermission('reservations.edit');
  bool get canApproveReservations => hasPermission('reservations.approve');
  bool get canCancelReservations => hasPermission('reservations.cancel');
  bool get canSpendReservations => hasPermission('reservations.spend');
  bool get canDeleteReservations => hasPermission('reservations.delete');

  bool get canAddExpenses => hasPermission('expenses.add');
  bool get canCancelExpenses => hasPermission('expenses.cancel');

  bool get canViewApiSettings => hasPermission('api_settings.view');
  bool get canEditApiSettings => hasPermission('api_settings.edit');

  bool get isViewOnly => !canModifyRecords;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
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
      'permissions': permissions,
    };
  }
}
