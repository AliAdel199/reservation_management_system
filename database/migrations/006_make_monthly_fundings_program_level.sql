-- تعليق عربي: تحويل التمويل الشهري ليكون على مستوى البرنامج بشكل عام بدلاً من إلزامه بباب محدد.
-- تبقى section_id اختيارية حتى لا تنكسر السجلات القديمة إن وجدت.

ALTER TABLE monthly_fundings
  ALTER COLUMN section_id DROP NOT NULL;

DROP INDEX IF EXISTS uq_monthly_fundings_active_scope;
DROP INDEX IF EXISTS uq_monthly_fundings_program_scope;
DROP INDEX IF EXISTS uq_monthly_fundings_section_scope;

-- تعليق عربي: يمنع تكرار تمويل نفس البرنامج لنفس الشهر وتاريخ التمويل عند عدم تحديد باب.
CREATE UNIQUE INDEX uq_monthly_fundings_program_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL AND section_id IS NULL;

-- تعليق عربي: دعم اختياري للبيانات القديمة التي كانت تمول على مستوى الباب.
CREATE UNIQUE INDEX uq_monthly_fundings_section_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    section_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL AND section_id IS NOT NULL;
