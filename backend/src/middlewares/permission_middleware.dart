import 'package:shelf/shelf.dart';

import '../models/app_exception.dart';
import '../models/request_user.dart';
import '../services/jwt_service.dart';
import 'auth_middleware.dart';
import 'request_context_keys.dart';

abstract final class PermissionCodes {
  static const viewRecords = 'view_records';
  static const modifyRecords = 'modify_records';
  static const deleteRecords = 'delete_records';
  static const manageUsers = 'manage_users';
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

      if (!_hasPermission(requestUser.roleCode, permission)) {
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

bool _hasPermission(String rawRoleCode, String permission) {
  final roleCode = rawRoleCode.trim().toUpperCase();
  if (roleCode == 'SUPER_ADMIN' || roleCode == 'SUPERADMIN') {
    return true;
  }

  if (permission == PermissionCodes.deleteRecords ||
      permission == PermissionCodes.manageUsers) {
    // تعليق عربي: الحذف وإدارة صلاحيات المستخدمين محصوران بالسوبر أدمن فقط.
    return false;
  }

  if (permission == PermissionCodes.viewRecords ||
      permission == PermissionCodes.viewReports) {
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

  if (permission == PermissionCodes.viewAuditLogs) {
    // تعليق عربي: سجل الإجراءات يحتوي تفاصيل حساسة، لذلك لا يظهر للمعاينة أو مدخل البيانات.
    return {
      'ADMIN',
      'FINANCE_MANAGER',
      'FINANCIAL_MANAGER',
      'REVIEWER',
      'FINANCIAL_AUDITOR',
    }.contains(roleCode);
  }

  if (permission == PermissionCodes.modifyRecords ||
      permission == PermissionCodes.manageSettings ||
      permission == PermissionCodes.exportReports) {
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

String _permissionMessage(String permission) {
  return switch (permission) {
    PermissionCodes.deleteRecords =>
      'Delete operations are allowed only for the super admin account.',
    PermissionCodes.manageUsers =>
      'User permissions can be managed only by the super admin account.',
    PermissionCodes.viewAuditLogs =>
      'Audit logs are not available for this account.',
    PermissionCodes.modifyRecords =>
      'This account has view-only access and cannot add or edit records.',
    _ => 'You do not have permission to perform this action.',
  };
}
