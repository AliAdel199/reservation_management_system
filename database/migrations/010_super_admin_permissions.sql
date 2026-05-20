-- تعليق عربي: توحيد أدوار الصلاحيات الأساسية وحصر الحذف وإدارة المستخدمين بالسوبر أدمن.

INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات: معاينة وإضافة وتعديل وحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إضافة وتعديل ومعاينة بدون صلاحية حذف'),
  ('DATA_ENTRY', 'إضافة وتعديل', 'إضافة وتعديل البيانات التشغيلية بدون حذف'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات والتقارير بدون إضافة أو تعديل أو حذف')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

UPDATE users u
SET role_id = sr.id
FROM roles old_role
CROSS JOIN roles sr
WHERE u.role_id = old_role.id
  AND LOWER(old_role.code) = 'super_admin'
  AND sr.code = 'SUPER_ADMIN';

UPDATE roles
SET
  name = 'سوبر أدمن',
  description = 'كل الصلاحيات: معاينة وإضافة وتعديل وحذف وإدارة المستخدمين'
WHERE LOWER(code) = 'super_admin';

INSERT INTO permissions (code, name, description)
VALUES
  ('view_records', 'معاينة فقط', 'السماح بعرض بيانات النظام'),
  ('modify_records', 'إضافة وتعديل', 'السماح بإضافة وتعديل البيانات بدون حذف'),
  ('delete_records', 'حذف', 'السماح بالحذف ويكون للسوبر أدمن فقط'),
  ('manage_users', 'إدارة المستخدمين', 'السماح بإنشاء المستخدمين وتحديد صلاحياتهم'),
  ('manage_settings', 'إدارة الإعدادات', 'السماح بإدارة الإعدادات الأساسية'),
  ('view_reports', 'عرض التقارير', 'السماح بعرض التقارير'),
  ('export_reports', 'تصدير التقارير', 'السماح بتصدير التقارير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

DELETE FROM role_permissions
USING roles r, permissions p
WHERE role_permissions.role_id = r.id
  AND role_permissions.permission_id = p.id
  AND p.code IN ('delete_records', 'manage_users')
  AND UPPER(r.code) <> 'SUPER_ADMIN';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE UPPER(r.code) = 'SUPER_ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'manage_settings',
  'view_reports',
  'export_reports'
)
WHERE UPPER(r.code) IN (
  'ADMIN',
  'DATA_ENTRY',
  'FINANCE_MANAGER',
  'FINANCIAL_MANAGER',
  'REVIEWER',
  'FINANCIAL_AUDITOR'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('view_records', 'view_reports')
WHERE UPPER(r.code) = 'VIEWER'
ON CONFLICT DO NOTHING;
