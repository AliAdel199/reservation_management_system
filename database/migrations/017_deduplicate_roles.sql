-- تعليق عربي: توحيد الأدوار القديمة والجديدة حتى لا تظهر صلاحيات مكررة في واجهة المستخدمين.
-- ننقل أي مستخدم على الدور القديم إلى الدور الرسمي، ثم نحذف الأدوار القديمة بعد تنظيف صلاحياتها.

INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات مع الحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إدارة النظام والاعتماد بدون صلاحية الحذف الحساسة'),
  ('FINANCE_MANAGER', 'مدير مالي', 'اعتماد الحجوزات والصرف والتقارير'),
  ('REVIEWER', 'مدقق مالي', 'مراجعة واعتماد العمليات المالية حسب الصلاحية'),
  ('DATA_ENTRY', 'إدخال بيانات', 'إدخال وتعديل البيانات التشغيلية بدون حذف حساس'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات بدون تعديل أو طباعة أو تصدير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

WITH role_map AS (
  SELECT old_role.id AS old_role_id, new_role.id AS new_role_id
  FROM (
    VALUES
      ('super_admin', 'SUPER_ADMIN'),
      ('financial_manager', 'FINANCE_MANAGER'),
      ('financial_auditor', 'REVIEWER'),
      ('data_entry', 'DATA_ENTRY')
  ) AS pairs(old_code, new_code)
  JOIN roles old_role ON old_role.code = pairs.old_code
  JOIN roles new_role ON new_role.code = pairs.new_code
)
UPDATE users u
SET role_id = role_map.new_role_id,
    updated_at = NOW()
FROM role_map
WHERE u.role_id = role_map.old_role_id;

DELETE FROM role_permissions rp
USING roles r
WHERE rp.role_id = r.id
  AND r.code IN ('super_admin', 'financial_manager', 'financial_auditor', 'data_entry');

DELETE FROM roles
WHERE code IN ('super_admin', 'financial_manager', 'financial_auditor', 'data_entry');
