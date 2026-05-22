-- تعليق عربي: عند صرف مبلغ أقل من الحجز، نحرر الجزء غير المصروف من المحجوز فقط.
-- التخصيص السنوي لا يتغير؛ التصحيح يؤثر على المحجوز والقابل للتصرف.

WITH active_spend AS (
  SELECT
    e.reservation_id,
    COALESCE(SUM(e.amount), 0) AS spent_amount
  FROM expenses e
  WHERE e.deleted_at IS NULL
    AND e.expense_status::text <> 'cancelled'
  GROUP BY e.reservation_id
),
hold_state AS (
  SELECT
    ft.reservation_id,
    COALESCE(SUM(
      CASE
        WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
        WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
        ELSE 0
      END
    ), 0) AS current_hold
  FROM financial_transactions ft
  WHERE ft.reservation_id IS NOT NULL
  GROUP BY ft.reservation_id
),
releases AS (
  SELECT
    r.id AS reservation_id,
    r.program_id,
    r.budget_section_id,
    r.funding_id,
    r.created_by,
    r.reservation_number,
    r.fiscal_year_id,
    r.budget_type_id,
    (COALESCE(hs.current_hold, 0) - asp.spent_amount) AS release_amount
  FROM reservations r
  JOIN active_spend asp ON asp.reservation_id = r.id
  LEFT JOIN hold_state hs ON hs.reservation_id = r.id
  WHERE r.deleted_at IS NULL
    AND r.workflow_status::text NOT IN ('cancelled')
    AND asp.spent_amount > 0
    AND asp.spent_amount < r.reserved_amount
    AND COALESCE(hs.current_hold, 0) > asp.spent_amount
)
INSERT INTO financial_transactions (
  id,
  transaction_number,
  transaction_type,
  reference_type,
  amount,
  direction,
  description,
  reference_table,
  reference_id,
  program_id,
  budget_section_id,
  section_id,
  funding_id,
  reservation_id,
  fiscal_year_id,
  budget_type_id,
  created_by
)
SELECT
  gen_random_uuid(),
  'RR-BACKFILL-' || EXTRACT(EPOCH FROM NOW())::bigint || '-' || LEFT(gen_random_uuid()::text, 8),
  'reservation_release'::transaction_type,
  'reservations',
  release_amount,
  'IN'::transaction_direction,
  'Backfill release for unused reservation hold ' || reservation_number,
  'reservations',
  reservation_id,
  program_id,
  budget_section_id,
  budget_section_id,
  funding_id,
  reservation_id,
  fiscal_year_id,
  budget_type_id,
  created_by
FROM releases
WHERE release_amount > 0;

WITH active_spend AS (
  SELECT
    e.reservation_id,
    COALESCE(SUM(e.amount), 0) AS spent_amount
  FROM expenses e
  WHERE e.deleted_at IS NULL
    AND e.expense_status::text <> 'cancelled'
  GROUP BY e.reservation_id
)
UPDATE reservations r
SET
  workflow_status = 'completed'::reservation_status,
  closed_at = COALESCE(r.closed_at, NOW())
FROM active_spend asp
WHERE asp.reservation_id = r.id
  AND r.deleted_at IS NULL
  AND r.workflow_status::text IN ('approved', 'partially_spent')
  AND asp.spent_amount > 0;
