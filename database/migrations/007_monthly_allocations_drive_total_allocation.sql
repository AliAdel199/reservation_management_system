-- تعليق عربي: التخصيص العام أصبح ناتج مجموع التخصيصات الشهرية النشطة.
-- إذا لم توجد تخصيصات شهرية بعد، نستخدم حركات التخصيص القديمة كقيمة احتياطية حتى لا تظهر اللوحة فارغة.

DROP VIEW IF EXISTS dashboard_financial_summary;

CREATE OR REPLACE VIEW dashboard_financial_summary AS
WITH monthly_allocation AS (
  SELECT COALESCE(SUM(amount), 0) AS total_allocation
  FROM monthly_fundings
  WHERE deleted_at IS NULL
),
ledger AS (
  SELECT
    COALESCE(SUM(CASE WHEN transaction_type::text IN ('allocation', 'adjustment_increase') THEN amount ELSE 0 END), 0) AS legacy_allocation,
    COALESCE(SUM(CASE
      WHEN transaction_type::text IN ('reservation_hold') THEN amount
      WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount
      ELSE 0
    END), 0) AS total_reserved,
    COALESCE(SUM(CASE
      WHEN transaction_type::text IN ('expense_disbursement') THEN amount
      WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount
      ELSE 0
    END), 0) AS total_spent
  FROM financial_transactions
),
totals AS (
  SELECT
    CASE
      WHEN ma.total_allocation > 0 THEN ma.total_allocation
      ELSE l.legacy_allocation
    END AS total_allocation,
    l.total_reserved,
    l.total_spent
  FROM monthly_allocation ma
  CROSS JOIN ledger l
)
SELECT
  total_allocation,
  total_allocation AS total_funding,
  total_reserved,
  total_spent,
  total_allocation - total_reserved AS remaining_balance,
  total_allocation - total_spent AS remaining_funding,
  LEAST(
    total_allocation - total_reserved,
    total_allocation - total_spent
  ) AS disposable_balance
FROM totals;
