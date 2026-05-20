-- تعليق عربي: ترقية تأسيسية تضيف السنوات المالية وأنواع الميزانية والتمويل الشهري بدون كسر الجداول الحالية.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_direction') THEN
    CREATE TYPE transaction_direction AS ENUM ('IN', 'OUT');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
    ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'fully_spent';
    ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'closed';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
    ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'funding';
    ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'reservation_cancel';
    ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'expense_cancel';
    ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'adjustment';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS fiscal_years (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  year INTEGER NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_fiscal_year_dates CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS budget_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(150) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (role_id, permission_id)
);

INSERT INTO fiscal_years (year, name, start_date, end_date, is_active)
SELECT
  EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
  'السنة المالية ' || EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
  make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 1, 1),
  make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 12, 31),
  TRUE
WHERE NOT EXISTS (SELECT 1 FROM fiscal_years);

INSERT INTO fiscal_years (year, name, start_date, end_date, is_active)
SELECT DISTINCT
  p.fiscal_year,
  'السنة المالية ' || p.fiscal_year,
  make_date(p.fiscal_year, 1, 1),
  make_date(p.fiscal_year, 12, 31),
  FALSE
FROM programs p
WHERE NOT EXISTS (
  SELECT 1 FROM fiscal_years fy WHERE fy.year = p.fiscal_year
);

INSERT INTO budget_types (code, name, description)
VALUES
  ('OPERATIONAL', 'تشغيلية', 'ميزانية تشغيلية عامة'),
  ('GOV_CATH', 'برنامج حكومي قسطرة', 'ميزانية برنامج حكومي للقسطرة'),
  ('GOV_ONCOLOGY', 'برنامج حكومي أورام', 'ميزانية برنامج حكومي للأورام'),
  ('SPECIAL_PROGRAMS', 'برامج خاصة', 'ميزانيات البرامج الخاصة')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

ALTER TABLE programs
  ADD COLUMN IF NOT EXISTS fiscal_year_id UUID REFERENCES fiscal_years(id),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

UPDATE programs p
SET fiscal_year_id = fy.id
FROM fiscal_years fy
WHERE p.fiscal_year_id IS NULL
  AND fy.year = p.fiscal_year;

ALTER TABLE budget_sections
  ADD COLUMN IF NOT EXISTS fiscal_year_id UUID REFERENCES fiscal_years(id),
  ADD COLUMN IF NOT EXISTS budget_type_id UUID REFERENCES budget_types(id),
  ADD COLUMN IF NOT EXISTS allocated_amount NUMERIC(18, 2) NOT NULL DEFAULT 0 CHECK (allocated_amount >= 0),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

UPDATE budget_sections bs
SET fiscal_year_id = p.fiscal_year_id
FROM programs p
WHERE bs.fiscal_year_id IS NULL
  AND p.id = bs.program_id;

UPDATE budget_sections bs
SET budget_type_id = bt.id
FROM budget_types bt
WHERE bs.budget_type_id IS NULL
  AND bt.code = 'OPERATIONAL';

ALTER TABLE fundings
  ADD COLUMN IF NOT EXISTS fiscal_year_id UUID REFERENCES fiscal_years(id),
  ADD COLUMN IF NOT EXISTS budget_type_id UUID REFERENCES budget_types(id),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

UPDATE fundings f
SET fiscal_year_id = fy.id
FROM fiscal_years fy
WHERE f.fiscal_year_id IS NULL
  AND fy.year = f.fiscal_year;

UPDATE fundings f
SET budget_type_id = bs.budget_type_id
FROM budget_sections bs
WHERE f.budget_type_id IS NULL
  AND bs.id = f.budget_section_id;

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS fiscal_year_id UUID REFERENCES fiscal_years(id),
  ADD COLUMN IF NOT EXISTS budget_type_id UUID REFERENCES budget_types(id),
  ADD COLUMN IF NOT EXISTS beneficiary VARCHAR(250),
  ADD COLUMN IF NOT EXISTS subject VARCHAR(300),
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS closed_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

UPDATE reservations r
SET
  fiscal_year_id = f.fiscal_year_id,
  budget_type_id = f.budget_type_id,
  subject = COALESCE(r.subject, r.title),
  notes = COALESCE(r.notes, r.description)
FROM fundings f
WHERE f.id = r.funding_id
  AND (r.fiscal_year_id IS NULL OR r.budget_type_id IS NULL);

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS payment_method VARCHAR(100),
  ADD COLUMN IF NOT EXISTS document_number VARCHAR(150),
  ADD COLUMN IF NOT EXISTS document_date DATE,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

UPDATE expenses
SET description = notes
WHERE description IS NULL
  AND notes IS NOT NULL;

CREATE TABLE IF NOT EXISTS monthly_fundings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_year_id UUID NOT NULL REFERENCES fiscal_years(id),
  budget_type_id UUID NOT NULL REFERENCES budget_types(id),
  program_id UUID NOT NULL REFERENCES programs(id),
  section_id UUID REFERENCES budget_sections(id),
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  funding_date DATE NOT NULL,
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES users(id)
);

ALTER TABLE monthly_fundings
  ALTER COLUMN section_id DROP NOT NULL;

ALTER TABLE financial_transactions
  ADD COLUMN IF NOT EXISTS reference_type VARCHAR(100),
  ADD COLUMN IF NOT EXISTS fiscal_year_id UUID REFERENCES fiscal_years(id),
  ADD COLUMN IF NOT EXISTS budget_type_id UUID REFERENCES budget_types(id),
  ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES budget_sections(id),
  ADD COLUMN IF NOT EXISTS direction transaction_direction;

UPDATE financial_transactions ft
SET
  reference_type = COALESCE(ft.reference_type, ft.reference_table),
  section_id = COALESCE(ft.section_id, ft.budget_section_id),
  fiscal_year_id = COALESCE(ft.fiscal_year_id, f.fiscal_year_id),
  budget_type_id = COALESCE(ft.budget_type_id, f.budget_type_id),
  direction = COALESCE(
    ft.direction,
    CASE
      WHEN ft.transaction_type::text IN (
        'allocation',
        'adjustment_increase',
        'reservation_release',
        'expense_reversal',
        'funding',
        'reservation_cancel',
        'expense_cancel',
        'adjustment'
      ) THEN 'IN'::transaction_direction
      ELSE 'OUT'::transaction_direction
    END
  )
FROM fundings f
WHERE ft.funding_id = f.id;

UPDATE financial_transactions
SET
  reference_type = COALESCE(reference_type, reference_table),
  section_id = COALESCE(section_id, budget_section_id),
  direction = COALESCE(
    direction,
    CASE
      WHEN transaction_type::text IN (
        'allocation',
        'adjustment_increase',
        'reservation_release',
        'expense_reversal',
        'funding',
        'reservation_cancel',
        'expense_cancel',
        'adjustment'
      ) THEN 'IN'::transaction_direction
      ELSE 'OUT'::transaction_direction
    END
  );

ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS entity_type VARCHAR(100);

UPDATE audit_logs
SET
  user_id = COALESCE(user_id, created_by),
  entity_type = COALESCE(entity_type, entity_name);

CREATE INDEX IF NOT EXISTS idx_programs_fiscal_year_id
  ON programs(fiscal_year_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_budget_sections_scope
  ON budget_sections(program_id, fiscal_year_id, budget_type_id, code)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_sections_program_year_code_active
  ON budget_sections(program_id, fiscal_year_id, LOWER(code))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_monthly_fundings_scope
  ON monthly_fundings(fiscal_year_id, budget_type_id, program_id, section_id, month)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_monthly_fundings_program_scope
  ON monthly_fundings(fiscal_year_id, budget_type_id, program_id, month, funding_date)
  WHERE deleted_at IS NULL AND section_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_monthly_fundings_section_scope
  ON monthly_fundings(fiscal_year_id, budget_type_id, program_id, section_id, month, funding_date)
  WHERE deleted_at IS NULL AND section_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_financial_transactions_modern_scope
  ON financial_transactions(
    fiscal_year_id,
    budget_type_id,
    program_id,
    section_id,
    direction,
    transaction_date
  );

DROP TRIGGER IF EXISTS trg_fiscal_years_updated_at ON fiscal_years;
CREATE TRIGGER trg_fiscal_years_updated_at
BEFORE UPDATE ON fiscal_years
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_budget_types_updated_at ON budget_types;
CREATE TRIGGER trg_budget_types_updated_at
BEFORE UPDATE ON budget_types
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_monthly_fundings_updated_at ON monthly_fundings;
CREATE TRIGGER trg_monthly_fundings_updated_at
BEFORE UPDATE ON monthly_fundings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW financial_ledger_summary AS
SELECT
  ft.fiscal_year_id,
  ft.budget_type_id,
  ft.program_id,
  COALESCE(ft.section_id, ft.budget_section_id) AS section_id,
  COALESCE(SUM(CASE WHEN ft.direction = 'IN' THEN ft.amount ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN ft.direction = 'OUT' THEN ft.amount ELSE 0 END), 0) AS total_out,
  COALESCE(SUM(
    CASE
      WHEN ft.direction = 'IN' THEN ft.amount
      WHEN ft.direction = 'OUT' THEN -ft.amount
      ELSE 0
    END
  ), 0) AS balance
FROM financial_transactions ft
GROUP BY
  ft.fiscal_year_id,
  ft.budget_type_id,
  ft.program_id,
  COALESCE(ft.section_id, ft.budget_section_id);

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
    COALESCE(SUM(CASE WHEN transaction_type::text IN ('reservation_hold') THEN amount WHEN transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -amount ELSE 0 END), 0) AS total_reserved,
    COALESCE(SUM(CASE WHEN transaction_type::text IN ('expense_disbursement') THEN amount WHEN transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -amount ELSE 0 END), 0) AS total_spent
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
