import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../services/jwt_service.dart';
import 'auth_middleware.dart';
import 'request_context_keys.dart';

abstract final class PermissionCodes {
  static const dashboardView = 'dashboard.view';
  static const alertsView = 'alerts.view';

  static const programsView = 'programs.view';
  static const programsAdd = 'programs.add';
  static const programsEdit = 'programs.edit';
  static const programsDelete = 'programs.delete';

  static const fiscalYearsView = 'fiscal_years.view';
  static const fiscalYearsAdd = 'fiscal_years.add';
  static const fiscalYearsEdit = 'fiscal_years.edit';
  static const fiscalYearsDelete = 'fiscal_years.delete';

  static const budgetTypesView = 'budget_types.view';
  static const budgetTypesAdd = 'budget_types.add';
  static const budgetTypesEdit = 'budget_types.edit';
  static const budgetTypesDelete = 'budget_types.delete';

  static const budgetSectionsView = 'budget_sections.view';
  static const budgetSectionsAdd = 'budget_sections.add';
  static const budgetSectionsEdit = 'budget_sections.edit';
  static const budgetSectionsDelete = 'budget_sections.delete';

  static const fundingsView = 'fundings.view';
  static const fundingsAdd = 'fundings.add';
  static const fundingsEdit = 'fundings.edit';
  static const fundingsDelete = 'fundings.delete';

  static const reservationsView = 'reservations.view';
  static const reservationsAdd = 'reservations.add';
  static const reservationsEdit = 'reservations.edit';
  static const reservationsDelete = 'reservations.delete';
  static const reservationsApprove = 'reservations.approve';
  static const reservationsCancel = 'reservations.cancel';
  static const reservationsSpend = 'reservations.spend';

  static const expensesView = 'expenses.view';
  static const expensesAdd = 'expenses.add';
  static const expensesCancel = 'expenses.cancel';

  static const reportsViewPage = 'reports.view';
  static const reportsPrint = 'reports.print';
  static const reportsExport = 'reports.export';

  static const institutionView = 'institution.view';
  static const institutionEdit = 'institution.edit';

  static const usersView = 'users.view';
  static const usersAdd = 'users.add';
  static const usersEdit = 'users.edit';

  static const auditLogsView = 'audit_logs.view';

  static const dataExchangeView = 'data_exchange.view';
  static const dataExchangeImport = 'data_exchange.import';
  static const dataExchangeExport = 'data_exchange.export';

  static const backupsView = 'backups.view';
  static const backupsCreate = 'backups.create';
  static const backupsRestore = 'backups.restore';

  static const apiSettingsView = 'api_settings.view';
  static const apiSettingsEdit = 'api_settings.edit';

  static const viewRecords = 'view_records';
  static const modifyRecords = 'modify_records';
  static const deleteRecords = 'delete_records';
  static const manageUsers = 'manage_users';
  static const manageBackups = 'manage_backups';
  static const manageSettings = 'manage_settings';
  static const viewReports = 'view_reports';
  static const exportReports = 'export_reports';
  static const viewAuditLogs = 'view_audit_logs';
}

Handler protectedRoute(
  JwtService jwtService,
  Handler handler, {
  String? permission,
}) {
  final authorizedHandler = permission == null
      ? handler
      : permissionMiddleware(permission)(handler);
  return authMiddleware(jwtService)(authorizedHandler);
}

Middleware permissionMiddleware(String permission) {
  return (innerHandler) {
    return (request) async {
      final requestUser =
          request.context[requestUserContextKey] as RequestUser?;
      if (requestUser == null) {
        throw const AppException(
          message: 'Authentication context is missing.',
          statusCode: 401,
          code: 'UNAUTHENTICATED',
        );
      }

      if (!_hasPermission(requestUser, permission)) {
        throw AppException(
          message: _permissionMessage(permission),
          statusCode: 403,
          code: 'FORBIDDEN',
        );
      }

      return innerHandler(request);
    };
  };
}

bool _hasPermission(RequestUser requestUser, String permission) {
  if (requestUser.hasPermission(permission)) {
    return true;
  }

  final roleCode = requestUser.roleCode.trim().toUpperCase();
  if (roleCode == 'SUPER_ADMIN' || roleCode == 'SUPERADMIN') {
    return true;
  }

  if (_superAdminOnlyPermissions.contains(permission)) {
    // تعليق عربي: الحذف وإدارة صلاحيات المستخدمين محصوران بالسوبر أدمن فقط.
    return false;
  }

  if (_viewPermissions.contains(permission)) {
    return {
      'ADMIN',
      'FINANCE_MANAGER',
      'FINANCIAL_MANAGER',
      'REVIEWER',
      'FINANCIAL_AUDITOR',
      'DATA_ENTRY',
      'VIEWER',
    }.contains(roleCode);
  }

  if (_auditPermissions.contains(permission)) {
    // تعليق عربي: سجل الإجراءات يحتوي تفاصيل حساسة، لذلك لا يظهر للمعاينة أو مدخل البيانات.
    return {
      'ADMIN',
      'FINANCE_MANAGER',
      'FINANCIAL_MANAGER',
      'REVIEWER',
      'FINANCIAL_AUDITOR',
    }.contains(roleCode);
  }

  if (_modifyPermissions.contains(permission)) {
    return {
      'ADMIN',
      'FINANCE_MANAGER',
      'FINANCIAL_MANAGER',
      'REVIEWER',
      'FINANCIAL_AUDITOR',
      'DATA_ENTRY',
    }.contains(roleCode);
  }

  return false;
}

const _superAdminOnlyPermissions = {
  PermissionCodes.deleteRecords,
  PermissionCodes.manageUsers,
  PermissionCodes.manageBackups,
  PermissionCodes.programsDelete,
  PermissionCodes.fiscalYearsDelete,
  PermissionCodes.budgetTypesDelete,
  PermissionCodes.budgetSectionsDelete,
  PermissionCodes.fundingsDelete,
  PermissionCodes.reservationsDelete,
  PermissionCodes.usersView,
  PermissionCodes.usersAdd,
  PermissionCodes.usersEdit,
  PermissionCodes.backupsView,
  PermissionCodes.backupsCreate,
  PermissionCodes.backupsRestore,
};

const _viewPermissions = {
  PermissionCodes.viewRecords,
  PermissionCodes.viewReports,
  PermissionCodes.dashboardView,
  PermissionCodes.alertsView,
  PermissionCodes.programsView,
  PermissionCodes.fiscalYearsView,
  PermissionCodes.budgetTypesView,
  PermissionCodes.budgetSectionsView,
  PermissionCodes.fundingsView,
  PermissionCodes.reservationsView,
  PermissionCodes.expensesView,
  PermissionCodes.reportsViewPage,
  PermissionCodes.institutionView,
  PermissionCodes.apiSettingsView,
};

const _auditPermissions = {
  PermissionCodes.viewAuditLogs,
  PermissionCodes.auditLogsView,
};

const _modifyPermissions = {
  PermissionCodes.modifyRecords,
  PermissionCodes.manageSettings,
  PermissionCodes.exportReports,
  PermissionCodes.programsAdd,
  PermissionCodes.programsEdit,
  PermissionCodes.fiscalYearsAdd,
  PermissionCodes.fiscalYearsEdit,
  PermissionCodes.budgetTypesAdd,
  PermissionCodes.budgetTypesEdit,
  PermissionCodes.budgetSectionsAdd,
  PermissionCodes.budgetSectionsEdit,
  PermissionCodes.fundingsAdd,
  PermissionCodes.fundingsEdit,
  PermissionCodes.reservationsAdd,
  PermissionCodes.reservationsEdit,
  PermissionCodes.reservationsApprove,
  PermissionCodes.reservationsCancel,
  PermissionCodes.reservationsSpend,
  PermissionCodes.expensesAdd,
  PermissionCodes.expensesCancel,
  PermissionCodes.reportsPrint,
  PermissionCodes.reportsExport,
  PermissionCodes.institutionEdit,
  PermissionCodes.dataExchangeView,
  PermissionCodes.dataExchangeImport,
  PermissionCodes.dataExchangeExport,
  PermissionCodes.apiSettingsEdit,
};

String _permissionMessage(String permission) {
  return switch (permission) {
    PermissionCodes.deleteRecords =>
      'Delete operations are allowed only for the super admin account.',
    PermissionCodes.programsDelete ||
    PermissionCodes.fiscalYearsDelete ||
    PermissionCodes.budgetTypesDelete ||
    PermissionCodes.budgetSectionsDelete ||
    PermissionCodes.fundingsDelete ||
    PermissionCodes.reservationsDelete =>
      'Delete operations are allowed only for the super admin account.',
    PermissionCodes.manageUsers =>
      'User permissions can be managed only by the super admin account.',
    PermissionCodes.usersView ||
    PermissionCodes.usersAdd ||
    PermissionCodes.usersEdit =>
      'User permissions can be managed only by the super admin account.',
    PermissionCodes.manageBackups =>
      'Database backup and restore is allowed only for the super admin account.',
    PermissionCodes.backupsView ||
    PermissionCodes.backupsCreate ||
    PermissionCodes.backupsRestore =>
      'Database backup and restore is allowed only for the super admin account.',
    PermissionCodes.viewAuditLogs =>
      'Audit logs are not available for this account.',
    PermissionCodes.auditLogsView =>
      'Audit logs are not available for this account.',
    PermissionCodes.modifyRecords =>
      'This account has view-only access and cannot add or edit records.',
    _ => 'You do not have permission to perform this action.',
  };
}
