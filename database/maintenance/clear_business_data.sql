-- تنظيف بيانات التشغيل قبل الاستيراد النظيف.
-- مهم: هذا الملف يمسح بيانات البرامج والأبواب والحجوزات والصرف والحركات المالية.
-- يبقي على المستخدمين، الأدوار، السنوات المالية، معلومات المؤسسة، والجداول المرجعية.

BEGIN;

-- تعليق عربي: نقفل الجداول المهمة أثناء التنظيف حتى لا تدخل عملية مالية بالتزامن.
LOCK TABLE
  audit_logs,
  expenses,
  reservations,
  financial_transactions,
  fundings,
  monthly_fundings,
  budget_sections,
  programs
IN ACCESS EXCLUSIVE MODE;

-- تعليق عربي: نستخدم TRUNCATE لأن المطلوب تصفير بيئة العمل قبل استيراد جديد.
TRUNCATE TABLE
  audit_logs,
  expenses,
  reservations,
  financial_transactions,
  fundings,
  monthly_fundings,
  budget_sections,
  programs
RESTART IDENTITY CASCADE;

COMMIT;

-- تعليق عربي: نتيجة سريعة للتأكد أن الجداول التشغيلية صارت فارغة.
SELECT 'programs' AS table_name, COUNT(*) AS rows_count FROM programs
UNION ALL SELECT 'budget_sections', COUNT(*) FROM budget_sections
UNION ALL SELECT 'fundings', COUNT(*) FROM fundings
UNION ALL SELECT 'monthly_fundings', COUNT(*) FROM monthly_fundings
UNION ALL SELECT 'reservations', COUNT(*) FROM reservations
UNION ALL SELECT 'expenses', COUNT(*) FROM expenses
UNION ALL SELECT 'financial_transactions', COUNT(*) FROM financial_transactions
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs
ORDER BY table_name;
