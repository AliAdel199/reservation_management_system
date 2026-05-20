import 'package:postgres/postgres.dart';

import '../models/request_user.dart';

class AuditService {
  const AuditService();

  Future<void> log({
    required Session session,
    required String action,
    required String entityName,
    String? entityId,
    RequestUser? actor,
    String? ipAddress,
    String? userAgent,
    String? description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    // تعليق عربي: نحتفظ بالأثر الرقابي لكل عملية مهمة لسهولة المراجعة اللاحقة.
    await session.execute(
      Sql.named('''
        INSERT INTO audit_logs (
          action,
          entity_name,
          entity_id,
          old_values,
          new_values,
          description,
          created_by,
          ip_address,
          user_agent
        )
        VALUES (
          @action,
          @entity_name,
          NULLIF(@entity_id, '')::uuid,
          @old_values::jsonb,
          @new_values::jsonb,
          @description,
          NULLIF(@created_by, '')::uuid,
          @ip_address,
          @user_agent
        )
      '''),
      parameters: {
        'action': action,
        'entity_name': entityName,
        'entity_id': entityId ?? '',
        'old_values': oldValues,
        'new_values': newValues,
        'description': description,
        'created_by': actor?.id ?? '',
        'ip_address': ipAddress,
        'user_agent': userAgent,
      },
    );
  }
}
