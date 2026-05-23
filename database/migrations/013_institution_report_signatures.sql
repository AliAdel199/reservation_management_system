-- تعليق عربي: بيانات القسم والشعبة وتواقيع التقارير الرسمية.
-- التواقيع تحفظ كـ JSONB حتى نستطيع إضافة 4-5 تواقيع بدون تغيير المخطط لاحقاً.

ALTER TABLE institution_settings
  ADD COLUMN IF NOT EXISTS section_name VARCHAR(250),
  ADD COLUMN IF NOT EXISTS division_name VARCHAR(250),
  ADD COLUMN IF NOT EXISTS show_report_signatures BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS report_signatures JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE institution_settings
SET report_signatures = '[]'::jsonb
WHERE report_signatures IS NULL;
