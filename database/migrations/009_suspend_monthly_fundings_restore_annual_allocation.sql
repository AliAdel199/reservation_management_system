-- تعليق عربي: تعليق مفهوم التمويل الشهري مؤقتاً والعودة للتخصيص السنوي للأبواب.
-- هذا الـ view احتياطي؛ الحسابات التشغيلية في الـ API تعتمد أيضاً على allocated_amount السنوي.

DROP VIEW IF EXISTS dashboard_financial_summary;

CREATE OR REPLACE VIEW dashboard_financial_summary AS
WITH allocation_fallback AS (
  SELECT
    f.budget_section_id AS section_id,
    COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
  FROM fundings f
  WHERE f.deleted_at IS NULL
  GROUP BY f.budget_section_id
),
annual_allocation AS (
  SELECT COALESCE(SUM(
    CASE
      WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
      ELSE COALESCE(af.total_allocation, 0)
    END
  ), 0) AS total_allocation
  FROM budget_sections bs
  LEFT JOIN allocation_fallback af ON af.section_id = bs.id
  WHERE bs.deleted_at IS NULL
),
ledger AS (
  SELECT
    COALESCE(SUM(CASE
      WHEN transaction_type::text = 'reservation_hold' THEN amount
      WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
      ELSE 0
    END), 0) AS total_reserved,
    COALESCE(SUM(CASE
      WHEN transaction_type::text = 'expense_disbursement' THEN amount
      WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
      ELSE 0
    END), 0) AS total_spent
  FROM financial_transactions
)
SELECT
  aa.total_allocation,
  0::numeric AS total_funding,
  l.total_reserved,
  l.total_spent,
  aa.total_allocation - l.total_reserved AS remaining_balance,
  0::numeric AS remaining_funding,
  aa.total_allocation - l.total_reserved AS disposable_balance
FROM annual_allocation aa
CROSS JOIN ledger l;
