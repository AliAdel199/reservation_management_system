-- تعليق عربي: ربط الحركات المالية القديمة بالسنة المالية ونوع الميزانية اعتماداً على الباب.
-- هذا مهم حتى تظهر الحجوزات والمصروفات القديمة في الداشبورد والتقارير عند اختيار سنة مالية.

UPDATE financial_transactions ft
SET
  section_id = COALESCE(ft.section_id, ft.budget_section_id),
  fiscal_year_id = COALESCE(ft.fiscal_year_id, bs.fiscal_year_id),
  budget_type_id = COALESCE(ft.budget_type_id, bs.budget_type_id)
FROM budget_sections bs
WHERE bs.id = COALESCE(ft.section_id, ft.budget_section_id)
  AND (
    ft.section_id IS NULL
    OR ft.fiscal_year_id IS NULL
    OR ft.budget_type_id IS NULL
  );

