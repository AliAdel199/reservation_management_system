-- تعليق عربي: إعدادات المؤسسة تستخدم في الترويسة الرسمية للتقارير والطباعة.
CREATE TABLE IF NOT EXISTS institution_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(250) NOT NULL DEFAULT 'المؤسسة الحكومية',
  ministry_name VARCHAR(250),
  department_name VARCHAR(250),
  address TEXT,
  phone VARCHAR(100),
  email VARCHAR(200),
  website VARCHAR(200),
  logo_path TEXT,
  document_header TEXT,
  document_footer TEXT,
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_institution_settings_updated_at ON institution_settings;
CREATE TRIGGER trg_institution_settings_updated_at
BEFORE UPDATE ON institution_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO institution_settings (
  name,
  ministry_name,
  department_name,
  document_header,
  document_footer
)
SELECT
  'المؤسسة الحكومية',
  'وزارة المالية',
  'دائرة المتابعة المالية',
  'نظام إدارة الحجوزات المالية الحكومية',
  'يعتمد التقرير على سجل الحركات المالية Ledger'
WHERE NOT EXISTS (SELECT 1 FROM institution_settings);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action
  ON audit_logs(action);

CREATE INDEX IF NOT EXISTS idx_users_role_active
  ON users(role_id, is_active);

-- تعليق عربي: نحافظ على توافق سجل الإجراءات مع التطويرات الحديثة بدون كسر الجداول القديمة.
ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS entity_type VARCHAR(100);

UPDATE audit_logs
SET
  user_id = COALESCE(user_id, created_by),
  entity_type = COALESCE(entity_type, entity_name);
