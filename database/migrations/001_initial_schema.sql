-- تعليق عربي: هذا المخطط يؤسس القاعدة المالية مع فصل السجل المالي Ledger عن الجداول التشغيلية.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
    CREATE TYPE reservation_status AS ENUM (
      'draft',
      'under_review',
      'approved',
      'partially_spent',
      'completed',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expense_status') THEN
    CREATE TYPE expense_status AS ENUM (
      'draft',
      'approved',
      'paid',
      'cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
    CREATE TYPE transaction_type AS ENUM (
      'allocation',
      'allocation_reversal',
      'reservation_hold',
      'reservation_release',
      'expense_disbursement',
      'expense_reversal',
      'adjustment_increase',
      'adjustment_decrease'
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(100) NOT NULL UNIQUE,
  full_name VARCHAR(200) NOT NULL,
  email VARCHAR(200) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role_id UUID NOT NULL REFERENCES roles(id),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  fiscal_year INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS budget_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_budget_sections_program_code UNIQUE (program_id, code)
);

CREATE TABLE IF NOT EXISTS fundings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES programs(id),
  budget_section_id UUID NOT NULL REFERENCES budget_sections(id),
  funding_reference VARCHAR(100) NOT NULL UNIQUE,
  fiscal_year INTEGER NOT NULL,
  allocated_amount NUMERIC(18, 2) NOT NULL CHECK (allocated_amount >= 0),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_number VARCHAR(100) NOT NULL UNIQUE,
  program_id UUID NOT NULL REFERENCES programs(id),
  budget_section_id UUID NOT NULL REFERENCES budget_sections(id),
  funding_id UUID NOT NULL REFERENCES fundings(id),
  title VARCHAR(250) NOT NULL,
  description TEXT,
  reserved_amount NUMERIC(18, 2) NOT NULL CHECK (reserved_amount > 0),
  workflow_status reservation_status NOT NULL DEFAULT 'draft',
  reservation_date DATE NOT NULL,
  approved_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id),
  expense_number VARCHAR(100) NOT NULL UNIQUE,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  expense_status expense_status NOT NULL DEFAULT 'draft',
  expense_date DATE NOT NULL,
  beneficiary_name VARCHAR(200),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  approved_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS financial_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_number VARCHAR(100) NOT NULL UNIQUE,
  transaction_type transaction_type NOT NULL,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  description TEXT,
  reference_table VARCHAR(100) NOT NULL,
  reference_id UUID,
  program_id UUID REFERENCES programs(id),
  budget_section_id UUID REFERENCES budget_sections(id),
  funding_id UUID REFERENCES fundings(id),
  reservation_id UUID REFERENCES reservations(id),
  expense_id UUID REFERENCES expenses(id),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action VARCHAR(100) NOT NULL,
  entity_name VARCHAR(100) NOT NULL,
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  description TEXT,
  created_by UUID REFERENCES users(id),
  ip_address VARCHAR(50),
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_programs_fiscal_year
  ON programs(fiscal_year);

CREATE INDEX IF NOT EXISTS idx_budget_sections_program_id
  ON budget_sections(program_id);

CREATE INDEX IF NOT EXISTS idx_fundings_program_section
  ON fundings(program_id, budget_section_id, fiscal_year);

CREATE INDEX IF NOT EXISTS idx_reservations_status
  ON reservations(workflow_status);

CREATE INDEX IF NOT EXISTS idx_reservations_funding_id
  ON reservations(funding_id);

CREATE INDEX IF NOT EXISTS idx_expenses_reservation_id
  ON expenses(reservation_id);

CREATE INDEX IF NOT EXISTS idx_financial_transactions_lookup
  ON financial_transactions(
    transaction_type,
    program_id,
    budget_section_id,
    funding_id,
    reservation_id,
    expense_id
  );

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
  ON audit_logs(entity_name, entity_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_roles_updated_at ON roles;
CREATE TRIGGER trg_roles_updated_at
BEFORE UPDATE ON roles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_programs_updated_at ON programs;
CREATE TRIGGER trg_programs_updated_at
BEFORE UPDATE ON programs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_budget_sections_updated_at ON budget_sections;
CREATE TRIGGER trg_budget_sections_updated_at
BEFORE UPDATE ON budget_sections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_fundings_updated_at ON fundings;
CREATE TRIGGER trg_fundings_updated_at
BEFORE UPDATE ON fundings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reservations_updated_at ON reservations;
CREATE TRIGGER trg_reservations_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_expenses_updated_at ON expenses;
CREATE TRIGGER trg_expenses_updated_at
BEFORE UPDATE ON expenses
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW dashboard_financial_summary AS
WITH totals AS (
  SELECT
    COALESCE(SUM(
      CASE
        WHEN transaction_type = 'allocation' THEN amount
        WHEN transaction_type = 'allocation_reversal' THEN -amount
        WHEN transaction_type = 'adjustment_increase' THEN amount
        WHEN transaction_type = 'adjustment_decrease' THEN -amount
        ELSE 0
      END
    ), 0) AS total_allocation,
    COALESCE(SUM(
      CASE
        WHEN transaction_type = 'reservation_hold' THEN amount
        WHEN transaction_type = 'reservation_release' THEN -amount
        ELSE 0
      END
    ), 0) AS total_reserved,
    COALESCE(SUM(
      CASE
        WHEN transaction_type = 'expense_disbursement' THEN amount
        WHEN transaction_type = 'expense_reversal' THEN -amount
        ELSE 0
      END
    ), 0) AS total_spent
  FROM financial_transactions
)
SELECT
  total_allocation,
  total_reserved,
  total_spent,
  total_allocation - total_reserved - total_spent AS remaining_balance
FROM totals;
