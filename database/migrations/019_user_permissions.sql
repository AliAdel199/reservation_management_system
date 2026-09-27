-- تعليق عربي: صلاحيات مخصصة لكل مستخدم لتطبيق فصل المهام (مثلاً: مُدخل الحجز غير المعتمِد).
-- الدور يبقى قالباً افتراضياً؛ عند تفعيل custom_permissions تحل صلاحيات المستخدم محل صلاحيات دوره.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS custom_permissions BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS user_permissions (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id
  ON user_permissions(user_id);
