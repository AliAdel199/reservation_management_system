-- تعليق عربي: القيد القديم كان يمنع إعادة إدخال تمويل شهري حتى لو كان السجل محذوفاً حذفاً ناعماً.
-- هذا التعديل يجعل منع التكرار مطبقاً على السجلات الفعالة فقط.

ALTER TABLE monthly_fundings
  DROP CONSTRAINT IF EXISTS uq_monthly_fundings_scope;

CREATE UNIQUE INDEX IF NOT EXISTS uq_monthly_fundings_active_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    section_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL;
