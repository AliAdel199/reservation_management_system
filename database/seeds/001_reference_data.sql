-- تعليق عربي: هذه البذور مرجعية ويمكن تشغيلها بأمان أكثر من مرة.

INSERT INTO roles (code, name, description)
VALUES
  ('super_admin', 'مدير النظام', 'صلاحيات كاملة على جميع الوحدات'),
  ('financial_manager', 'مدير مالي', 'إدارة الاعتماد والمتابعة والتقارير'),
  ('financial_auditor', 'مدقق مالي', 'مراجعة العمليات واعتمادها'),
  ('data_entry', 'إدخال بيانات', 'إدخال البرامج والأبواب والحجوزات الأولية')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();
