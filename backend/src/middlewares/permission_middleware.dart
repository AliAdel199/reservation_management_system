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
  static const fiscalYearsLock = 'fiscal_years.lock';

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
          message: 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
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

// تعليق عربي: الصلاحيات تأتي من قاعدة البيانات فقط (صلاحيات الدور أو الصلاحيات المخصصة للمستخدم).
// أُزيلت المنح الضمنية حسب رمز الدور لأنها كانت تتجاوز ما يضبطه المدير، فمثلاً كان مدخل البيانات
// يستطيع اعتماد الحجز وصرفه عبر الـ API رغم عدم امتلاكه الصلاحية، مما يلغي فصل المهام.
bool _hasPermission(RequestUser requestUser, String permission) =>
    requestUser.hasPermission(permission);

// تعليق عربي: الصلاحيات تُمنح لكل مستخدم، فالرسالة لا تفترض أن الإجراء محصور بدور معيّن.
String _permissionMessage(String permission) =>
    'ليس لديك صلاحية لتنفيذ هذا الإجراء. راجع مدير النظام لمنحك الصلاحية.';
