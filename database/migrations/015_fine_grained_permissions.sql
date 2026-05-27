-- تعليق عربي: صلاحيات دقيقة حسب الصفحة والعملية مع الحفاظ على الصلاحيات القديمة كتوافق خلفي.

INSERT INTO permissions (code, name, description)
VALUES
  ('dashboard.view', 'عرض لوحة التحكم', 'السماح بعرض لوحة التحكم والملخصات'),
  ('alerts.view', 'عرض التنبيهات', 'السماح بعرض تنبيهات الأرصدة'),
  ('programs.view', 'عرض البرامج', 'السماح بعرض البرامج'),
  ('programs.add', 'إضافة برنامج', 'السماح بإضافة البرامج'),
  ('programs.edit', 'تعديل برنامج', 'السماح بتعديل البرامج'),
  ('programs.delete', 'حذف برنامج', 'السماح بحذف البرامج'),
  ('fiscal_years.view', 'عرض السنوات المالية', 'السماح بعرض السنوات المالية'),
  ('fiscal_years.add', 'إضافة سنة مالية', 'السماح بإضافة السنوات المالية'),
  ('fiscal_years.edit', 'تعديل سنة مالية', 'السماح بتعديل أو تفعيل السنوات المالية'),
  ('fiscal_years.delete', 'حذف سنة مالية', 'السماح بحذف السنوات المالية'),
  ('budget_types.view', 'عرض أنواع الميزانية', 'السماح بعرض أنواع الميزانية'),
  ('budget_types.add', 'إضافة نوع ميزانية', 'السماح بإضافة أنواع الميزانية'),
  ('budget_types.edit', 'تعديل نوع ميزانية', 'السماح بتعديل أنواع الميزانية'),
  ('budget_types.delete', 'حذف نوع ميزانية', 'السماح بحذف أنواع الميزانية'),
  ('budget_sections.view', 'عرض الأبواب', 'السماح بعرض الأبواب المالية'),
  ('budget_sections.add', 'إضافة باب', 'السماح بإضافة الأبواب المالية'),
  ('budget_sections.edit', 'تعديل باب', 'السماح بتعديل الأبواب المالية'),
  ('budget_sections.delete', 'حذف باب', 'السماح بحذف الأبواب المالية'),
  ('fundings.view', 'عرض التخصيصات', 'السماح بعرض التخصيصات'),
  ('fundings.add', 'إضافة تخصيص', 'السماح بإضافة التخصيصات'),
  ('fundings.edit', 'تعديل تخصيص', 'السماح بتعديل التخصيصات'),
  ('fundings.delete', 'حذف تخصيص', 'السماح بحذف التخصيصات'),
  ('reservations.view', 'عرض الحجوزات', 'السماح بعرض الحجوزات'),
  ('reservations.add', 'إضافة حجز', 'السماح بإضافة الحجوزات'),
  ('reservations.edit', 'تعديل حجز', 'السماح بتعديل الحجوزات'),
  ('reservations.delete', 'حذف حجز', 'السماح بحذف الحجوزات'),
  ('reservations.approve', 'اعتماد حجز', 'السماح باعتماد الحجوزات'),
  ('reservations.cancel', 'إلغاء حجز', 'السماح بإلغاء الحجوزات'),
  ('reservations.spend', 'صرف من حجز', 'السماح بإنشاء صرف من الحجز'),
  ('expenses.view', 'عرض الصرف', 'السماح بعرض المصروفات'),
  ('expenses.add', 'إضافة صرف', 'السماح بإضافة المصروفات'),
  ('expenses.cancel', 'إلغاء صرف', 'السماح بإلغاء المصروفات'),
  ('reports.view', 'عرض التقارير', 'السماح بعرض التقارير'),
  ('reports.print', 'طباعة التقارير', 'السماح بطباعة التقارير'),
  ('reports.export', 'تصدير التقارير', 'السماح بتصدير التقارير'),
  ('institution.view', 'عرض معلومات المؤسسة', 'السماح بعرض معلومات المؤسسة'),
  ('institution.edit', 'تعديل معلومات المؤسسة', 'السماح بتعديل معلومات المؤسسة'),
  ('users.view', 'عرض المستخدمين', 'السماح بعرض المستخدمين'),
  ('users.add', 'إضافة مستخدم', 'السماح بإضافة المستخدمين'),
  ('users.edit', 'تعديل مستخدم', 'السماح بتعديل المستخدمين وكلمات المرور'),
  ('audit_logs.view', 'عرض سجل الإجراءات', 'السماح بعرض سجل الإجراءات'),
  ('data_exchange.view', 'عرض الاستيراد والتصدير', 'السماح بفتح صفحة الاستيراد والتصدير'),
  ('data_exchange.import', 'استيراد بيانات', 'السماح باستيراد البيانات من Excel'),
  ('data_exchange.export', 'تصدير بيانات', 'السماح بتصدير البيانات إلى Excel'),
  ('backups.view', 'عرض النسخ الاحتياطي', 'السماح بعرض النسخ الاحتياطية'),
  ('backups.create', 'إنشاء نسخة احتياطية', 'السماح بإنشاء نسخة احتياطية'),
  ('backups.restore', 'استرجاع نسخة احتياطية', 'السماح باسترجاع نسخة احتياطية'),
  ('api_settings.view', 'عرض إعداد الاتصال', 'السماح بعرض إعدادات اتصال الخادم'),
  ('api_settings.edit', 'تعديل إعداد الاتصال', 'السماح بتعديل إعدادات اتصال الخادم')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE UPPER(r.code) IN ('SUPER_ADMIN', 'SUPERADMIN')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'manage_settings',
  'view_reports',
  'export_reports',
  'view_audit_logs',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'programs.add',
  'programs.edit',
  'fiscal_years.view',
  'fiscal_years.add',
  'fiscal_years.edit',
  'budget_types.view',
  'budget_types.add',
  'budget_types.edit',
  'budget_sections.view',
  'budget_sections.add',
  'budget_sections.edit',
  'fundings.view',
  'fundings.add',
  'fundings.edit',
  'reservations.view',
  'reservations.add',
  'reservations.edit',
  'reservations.approve',
  'reservations.cancel',
  'reservations.spend',
  'expenses.view',
  'expenses.add',
  'expenses.cancel',
  'reports.view',
  'reports.print',
  'reports.export',
  'institution.view',
  'institution.edit',
  'audit_logs.view',
  'data_exchange.view',
  'data_exchange.import',
  'data_exchange.export',
  'api_settings.view',
  'api_settings.edit'
)
WHERE UPPER(r.code) = 'ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'view_reports',
  'export_reports',
  'view_audit_logs',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'fiscal_years.view',
  'budget_types.view',
  'budget_sections.view',
  'fundings.view',
  'reservations.view',
  'reservations.edit',
  'reservations.approve',
  'reservations.cancel',
  'reservations.spend',
  'expenses.view',
  'expenses.add',
  'expenses.cancel',
  'reports.view',
  'reports.print',
  'reports.export',
  'institution.view',
  'audit_logs.view',
  'api_settings.view'
)
WHERE UPPER(r.code) IN ('FINANCE_MANAGER', 'FINANCIAL_MANAGER', 'REVIEWER', 'FINANCIAL_AUDITOR')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'view_reports',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'programs.add',
  'programs.edit',
  'fiscal_years.view',
  'budget_sections.view',
  'budget_sections.add',
  'budget_sections.edit',
  'fundings.view',
  'reservations.view',
  'reservations.add',
  'reservations.edit',
  'expenses.view',
  'expenses.add',
  'reports.view',
  'institution.view',
  'api_settings.view'
)
WHERE UPPER(r.code) IN ('DATA_ENTRY', 'data_entry')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'view_reports',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'fiscal_years.view',
  'budget_sections.view',
  'fundings.view',
  'reservations.view',
  'expenses.view',
  'reports.view',
  'institution.view',
  'api_settings.view'
)
WHERE UPPER(r.code) = 'VIEWER'
ON CONFLICT DO NOTHING;

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) NOT IN ('SUPER_ADMIN', 'SUPERADMIN')
  AND p.code IN (
    'delete_records',
    'manage_users',
    'manage_backups',
    'programs.delete',
    'fiscal_years.delete',
    'budget_types.delete',
    'budget_sections.delete',
    'fundings.delete',
    'reservations.delete',
    'users.view',
    'users.add',
    'users.edit',
    'backups.view',
    'backups.create',
    'backups.restore'
  );

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) NOT IN ('SUPER_ADMIN', 'SUPERADMIN', 'ADMIN')
  AND p.code IN (
    'data_exchange.view',
    'data_exchange.import',
    'data_exchange.export'
  );

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) IN ('VIEWER', 'DATA_ENTRY')
  AND p.code IN (
    'view_audit_logs',
    'audit_logs.view',
    'export_reports',
    'reports.print',
    'reports.export'
  );
