-- تعليق عربي: عنوان التقرير الرسمي يظهر في منتصف هيدر الطباعة ويمكن تعديله من معلومات المؤسسة.

ALTER TABLE institution_settings
  ADD COLUMN IF NOT EXISTS report_title VARCHAR(250);

UPDATE institution_settings
SET report_title = COALESCE(NULLIF(report_title, ''), 'تقرير ملخص الباب')
WHERE report_title IS NULL OR report_title = '';
