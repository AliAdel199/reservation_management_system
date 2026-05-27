-- تعليق عربي: بيانات مرجعية للمرحلة المالية الجديدة، قابلة للتشغيل أكثر من مرة.

INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات مع الحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إدارة النظام والاعتماد بدون صلاحية الحذف الحساسة'),
  ('DATA_ENTRY', 'إدخال بيانات', 'إدخال وتعديل البيانات التشغيلية بدون حذف حساس'),
  ('REVIEWER', 'مدقق مالي', 'مراجعة واعتماد العمليات المالية حسب الصلاحية'),
  ('FINANCE_MANAGER', 'مدير مالي', 'اعتماد الحجوزات والصرف والتقارير'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات بدون تعديل أو طباعة أو تصدير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

INSERT INTO permissions (code, name, description)
VALUES
  ('create_reservation', 'إنشاء حجز', 'السماح بإنشاء الحجوزات'),
  ('approve_reservation', 'اعتماد حجز', 'السماح باعتماد الحجوزات'),
  ('cancel_reservation', 'إلغاء حجز', 'السماح بإلغاء الحجوزات'),
  ('create_expense', 'إنشاء صرف', 'السماح بتسجيل المصروفات'),
  ('cancel_expense', 'إلغاء صرف', 'السماح بإلغاء المصروفات'),
  ('view_reports', 'عرض التقارير', 'السماح بعرض التقارير'),
  ('export_reports', 'تصدير التقارير', 'السماح بتصدير التقارير'),
  ('view_audit_logs', 'عرض سجل الإجراءات', 'السماح بمتابعة سجل الإجراءات'),
  ('manage_users', 'إدارة المستخدمين', 'السماح بإدارة المستخدمين والصلاحيات'),
  ('manage_settings', 'إدارة الإعدادات', 'السماح بإدارة السنوات المالية وأنواع الميزانيات')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code IN ('ADMIN', 'super_admin')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'create_reservation',
  'approve_reservation',
  'cancel_reservation',
  'create_expense',
  'cancel_expense',
  'view_reports',
  'export_reports',
  'view_audit_logs'
)
WHERE r.code IN ('FINANCE_MANAGER', 'financial_manager')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'approve_reservation',
  'view_reports',
  'view_audit_logs'
)
WHERE r.code IN ('REVIEWER', 'financial_auditor')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'create_reservation',
  'create_expense'
)
WHERE r.code = 'DATA_ENTRY'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'view_reports'
WHERE r.code = 'VIEWER'
ON CONFLICT DO NOTHING;

INSERT INTO budget_types (code, name, description)
VALUES
  ('OPERATIONAL', 'تشغيلية', 'ميزانية تشغيلية عامة'),
  ('GOV_CATH', 'برنامج حكومي قسطرة', 'ميزانية برنامج حكومي للقسطرة'),
  ('GOV_ONCOLOGY', 'برنامج حكومي أورام', 'ميزانية برنامج حكومي للأورام'),
  ('SPECIAL_PROGRAMS', 'برامج خاصة', 'ميزانيات البرامج الخاصة')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();
