-- تعليق عربي: سجل التدقيق في نظام مالي حكومي يجب أن يكون للإضافة فقط.
-- هذا الـ trigger يمنع تعديل أو حذف أي صف من audit_logs حتى من داخل التطبيق أو من اتصال SQL مباشر.
-- ملاحظة: TRUNCATE لا يمر عبر triggers الصفوف؛ سكربت الصيانة clear_business_data.sql ما زال يستطيع
-- تصفير السجل عند تنفيذه عمداً بصلاحيات مالك القاعدة.

-- تعليق عربي: نكمل الأعمدة التوافقية للصفوف القديمة قبل القفل، حتى لا تحتاج تعديلاً لاحقاً.
UPDATE audit_logs
SET
  user_id = COALESCE(user_id, created_by),
  entity_type = COALESCE(entity_type, entity_name)
WHERE (user_id IS NULL AND created_by IS NOT NULL)
   OR (entity_type IS NULL AND entity_name IS NOT NULL);

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only: % is not allowed', TG_OP
    USING ERRCODE = 'insufficient_privilege';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON audit_logs;
CREATE TRIGGER trg_audit_logs_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW
EXECUTE FUNCTION prevent_audit_log_mutation();
