-- تعليق عربي: تصحيح معادلة الداشبورد حتى لا يتم خصم الصرف مرتين من نفس الحجز.
-- الحجز يحجز المبلغ من الباب، والصرف المنفذ على نفس الحجز لا يخصم مرة ثانية من متبقي الباب.

DROP VIEW IF EXISTS dashboard_financial_summary;

CREATE OR REPLACE VIEW dashboard_financial_summary AS
WITH totals AS (
  SELECT
    COALESCE(SUM(CASE WHEN transaction_type::text IN ('allocation', 'adjustment_increase') THEN amount ELSE 0 END), 0) AS total_allocation,
    COALESCE(SUM(CASE WHEN transaction_type::text IN ('funding') THEN amount ELSE 0 END), 0) AS total_funding,
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
)
SELECT
  total_allocation,
  total_funding,
  total_reserved,
  total_spent,
  total_allocation - total_reserved AS remaining_balance,
  total_funding - total_spent AS remaining_funding,
  LEAST(
    total_allocation - total_reserved,
    CASE WHEN total_funding > 0 THEN total_funding - total_spent ELSE total_allocation - total_reserved END
  ) AS disposable_balance
FROM totals;
