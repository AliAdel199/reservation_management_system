-- Reservation Management System - Customer Database Setup
-- Generated from project migrations and seeds. Run once on customer PostgreSQL database.
-- آخر تحديث: يشمل جميع تعديلات قاعدة البيانات حتى migration رقم 017.
-- ملاحظة عربية: التمويل الشهري معلّق حالياً، والتخصيص المعتمد هو التخصيص السنوي للأبواب.
-- مصادر الملف:
-- 001_initial_schema.sql
-- 002_financial_foundation_upgrade.sql
-- 003_fix_dashboard_remaining_formula.sql
-- 004_add_expense_document_date.sql
-- 005_fix_monthly_fundings_soft_delete_unique.sql
-- 006_institution_settings.sql
-- 006_make_monthly_fundings_program_level.sql
-- 007_monthly_allocations_drive_total_allocation.sql
-- 008_backfill_financial_transaction_scope.sql
-- 009_suspend_monthly_fundings_restore_annual_allocation.sql
-- 012_release_partial_spent_reservation_remainder.sql
-- 013_institution_report_signatures.sql
-- 014_institution_report_title.sql
-- 015_fine_grained_permissions.sql
-- 016_document_attachments.sql
-- 017_deduplicate_roles.sql
-- 001_reference_data.sql
-- 002_financial_foundation_data.sql

BEGIN;


-- ============================================================
-- Source: database/migrations/001_initial_schema.sql
-- ============================================================

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


-- ============================================================
-- Source: database/migrations/002_financial_foundation_upgrade.sql
-- ============================================================

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
  ADD COLUMN IF NOT EXISTS execution_note TEXT,
  ADD COLUMN IF NOT EXISTS requester_department VARCHAR(250),
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(100),
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

UPDATE reservations
SET beneficiary = COALESCE(NULLIF(beneficiary, ''), title)
WHERE beneficiary IS NULL OR beneficiary = '';

CREATE INDEX IF NOT EXISTS idx_reservations_beneficiary
  ON reservations(LOWER(beneficiary));

CREATE INDEX IF NOT EXISTS idx_reservations_requester_department
  ON reservations(LOWER(requester_department));

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


-- ============================================================
-- Source: database/migrations/003_fix_dashboard_remaining_formula.sql
-- ============================================================

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


-- ============================================================
-- Source: database/migrations/004_add_expense_document_date.sql
-- ============================================================

-- تعليق عربي: تاريخ المستند يساعد في مطابقة الصرف مع الكتب/الوصولات الرسمية.
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS document_date DATE;


-- ============================================================
-- Source: database/migrations/005_fix_monthly_fundings_soft_delete_unique.sql
-- ============================================================

-- تعليق عربي: القيد القديم كان يمنع إعادة إدخال تمويل شهري حتى لو كان السجل محذوفاً حذفاً ناعماً.
-- هذا التعديل يجعل منع التكرار مطبقاً على السجلات الفعالة فقط.

ALTER TABLE monthly_fundings
  DROP CONSTRAINT IF EXISTS uq_monthly_fundings_scope;

CREATE UNIQUE INDEX IF NOT EXISTS uq_monthly_fundings_active_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    section_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL;


-- ============================================================
-- Source: database/migrations/006_institution_settings.sql
-- ============================================================

-- تعليق عربي: إعدادات المؤسسة تستخدم في الترويسة الرسمية للتقارير والطباعة.
CREATE TABLE IF NOT EXISTS institution_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(250) NOT NULL DEFAULT 'المؤسسة الحكومية',
  ministry_name VARCHAR(250),
  department_name VARCHAR(250),
  section_name VARCHAR(250),
  division_name VARCHAR(250),
  address TEXT,
  phone VARCHAR(100),
  email VARCHAR(200),
  website VARCHAR(200),
  logo_path TEXT,
  document_header TEXT,
  document_footer TEXT,
  report_title VARCHAR(250),
  show_report_signatures BOOLEAN NOT NULL DEFAULT FALSE,
  report_signatures JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_institution_settings_updated_at ON institution_settings;
CREATE TRIGGER trg_institution_settings_updated_at
BEFORE UPDATE ON institution_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO institution_settings (
  name,
  ministry_name,
  department_name,
  document_header,
  document_footer
)
SELECT
  'المؤسسة الحكومية',
  'وزارة المالية',
  'دائرة المتابعة المالية',
  'نظام إدارة الحجوزات المالية الحكومية',
  'يعتمد التقرير على سجل الحركات المالية Ledger'
WHERE NOT EXISTS (SELECT 1 FROM institution_settings);

-- ============================================================
-- Source: database/migrations/013_institution_report_signatures.sql
-- ============================================================

-- تعليق عربي: بيانات القسم والشعبة وتواقيع التقارير الرسمية.
ALTER TABLE institution_settings
  ADD COLUMN IF NOT EXISTS section_name VARCHAR(250),
  ADD COLUMN IF NOT EXISTS division_name VARCHAR(250),
  ADD COLUMN IF NOT EXISTS show_report_signatures BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS report_signatures JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE institution_settings
SET report_signatures = '[]'::jsonb
WHERE report_signatures IS NULL;

-- ============================================================
-- Source: database/migrations/014_institution_report_title.sql
-- ============================================================

-- تعليق عربي: عنوان التقرير الرسمي يظهر في منتصف هيدر الطباعة ويمكن تعديله من معلومات المؤسسة.
ALTER TABLE institution_settings
  ADD COLUMN IF NOT EXISTS report_title VARCHAR(250);

UPDATE institution_settings
SET report_title = COALESCE(NULLIF(report_title, ''), 'تقرير ملخص الباب')
WHERE report_title IS NULL OR report_title = '';

-- ============================================================
-- Hierarchical budget sections
-- تعليق عربي: دعم شجرة الأبواب المالية بدون كسر البيانات القديمة.
-- الأبواب الموجودة تتحول إلى أبواب نهائية قابلة للتخصيص والحجز والصرف.
-- ============================================================
ALTER TABLE budget_sections
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES budget_sections(id),
  ADD COLUMN IF NOT EXISTS level INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS full_code VARCHAR(300),
  ADD COLUMN IF NOT EXISTS is_postable BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS path TEXT;

UPDATE budget_sections
SET
  level = COALESCE(NULLIF(level, 0), 1),
  full_code = COALESCE(NULLIF(full_code, ''), code),
  is_postable = COALESCE(is_postable, TRUE),
  sort_order = COALESCE(sort_order, 0),
  path = COALESCE(NULLIF(path, ''), id::text)
WHERE full_code IS NULL
   OR path IS NULL
   OR level IS NULL;

DROP INDEX IF EXISTS uq_budget_sections_program_year_code_active;
ALTER TABLE budget_sections DROP CONSTRAINT IF EXISTS uq_budget_sections_program_code;
ALTER TABLE budget_sections DROP CONSTRAINT IF EXISTS budget_sections_program_id_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_sections_sibling_code_active
  ON budget_sections(
    program_id,
    fiscal_year_id,
    COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    LOWER(code)
  )
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_sections_full_code_active
  ON budget_sections(program_id, fiscal_year_id, LOWER(full_code))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_budget_sections_parent
  ON budget_sections(parent_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_budget_sections_path
  ON budget_sections(path);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_budget_sections_parent_not_self'
  ) THEN
    ALTER TABLE budget_sections
      ADD CONSTRAINT chk_budget_sections_parent_not_self
      CHECK (parent_id IS NULL OR parent_id <> id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action
  ON audit_logs(action);

CREATE INDEX IF NOT EXISTS idx_users_role_active
  ON users(role_id, is_active);

-- تعليق عربي: نحافظ على توافق سجل الإجراءات مع التطويرات الحديثة بدون كسر الجداول القديمة.
ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS entity_type VARCHAR(100);

UPDATE audit_logs
SET
  user_id = COALESCE(user_id, created_by),
  entity_type = COALESCE(entity_type, entity_name);


-- ============================================================
-- Source: database/migrations/006_make_monthly_fundings_program_level.sql
-- ============================================================

-- تعليق عربي: تحويل التمويل الشهري ليكون على مستوى البرنامج بشكل عام بدلاً من إلزامه بباب محدد.
-- تبقى section_id اختيارية حتى لا تنكسر السجلات القديمة إن وجدت.

ALTER TABLE monthly_fundings
  ALTER COLUMN section_id DROP NOT NULL;

DROP INDEX IF EXISTS uq_monthly_fundings_active_scope;
DROP INDEX IF EXISTS uq_monthly_fundings_program_scope;
DROP INDEX IF EXISTS uq_monthly_fundings_section_scope;

-- تعليق عربي: يمنع تكرار تمويل نفس البرنامج لنفس الشهر وتاريخ التمويل عند عدم تحديد باب.
CREATE UNIQUE INDEX uq_monthly_fundings_program_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL AND section_id IS NULL;

-- تعليق عربي: دعم اختياري للبيانات القديمة التي كانت تمول على مستوى الباب.
CREATE UNIQUE INDEX uq_monthly_fundings_section_scope
  ON monthly_fundings (
    fiscal_year_id,
    budget_type_id,
    program_id,
    section_id,
    month,
    funding_date
  )
  WHERE deleted_at IS NULL AND section_id IS NOT NULL;


-- ============================================================
-- Source: database/migrations/007_monthly_allocations_drive_total_allocation.sql
-- ============================================================

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


-- ============================================================
-- Source: database/seeds/001_reference_data.sql
-- ============================================================

-- تعليق عربي: هذه البذور مرجعية ويمكن تشغيلها بأمان أكثر من مرة.

INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات مع الحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إدارة النظام والاعتماد بدون صلاحية الحذف الحساسة'),
  ('FINANCE_MANAGER', 'مدير مالي', 'اعتماد الحجوزات والصرف والتقارير'),
  ('REVIEWER', 'مدقق مالي', 'مراجعة واعتماد العمليات المالية حسب الصلاحية'),
  ('DATA_ENTRY', 'إدخال بيانات', 'إدخال وتعديل البيانات التشغيلية بدون حذف حساس'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات بدون تعديل أو طباعة أو تصدير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();


-- ============================================================
-- Source: database/seeds/002_financial_foundation_data.sql
-- ============================================================

-- تعليق عربي: بيانات مرجعية للمرحلة المالية الجديدة، قابلة للتشغيل أكثر من مرة.

INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات مع الحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إدارة النظام والاعتماد بدون صلاحية الحذف الحساسة'),
  ('DATA_ENTRY', 'إدخال بيانات', 'إدخال وتعديل البيانات التشغيلية بدون حذف حساس'),
  ('REVIEWER', 'مدقق مالي', 'مراجعة واعتماد العمليات المالية حسب الصلاحية'),
  ('FINANCE_MANAGER', 'مدير مالي', 'اعتماد الحجوزات والصرف والتقارير'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات بدون تعديل أو طباعة أو تصدير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

INSERT INTO permissions (code, name, description)
VALUES
  ('create_reservation', 'إنشاء حجز', 'السماح بإنشاء الحجوزات'),
  ('approve_reservation', 'اعتماد حجز', 'السماح باعتماد الحجوزات'),
  ('cancel_reservation', 'إلغاء حجز', 'السماح بإلغاء الحجوزات'),
  ('create_expense', 'إنشاء صرف', 'السماح بتسجيل المصروفات'),
  ('cancel_expense', 'إلغاء صرف', 'السماح بإلغاء المصروفات'),
  ('view_reports', 'عرض التقارير', 'السماح بعرض التقارير'),
  ('export_reports', 'تصدير التقارير', 'السماح بتصدير التقارير'),
  ('view_audit_logs', 'عرض سجل الإجراءات', 'السماح بمتابعة سجل الإجراءات'),
  ('manage_users', 'إدارة المستخدمين', 'السماح بإدارة المستخدمين والصلاحيات'),
  ('manage_settings', 'إدارة الإعدادات', 'السماح بإدارة السنوات المالية وأنواع الميزانيات')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code IN ('ADMIN', 'super_admin')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'create_reservation',
  'approve_reservation',
  'cancel_reservation',
  'create_expense',
  'cancel_expense',
  'view_reports',
  'export_reports',
  'view_audit_logs'
)
WHERE r.code IN ('FINANCE_MANAGER', 'financial_manager')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'approve_reservation',
  'view_reports',
  'view_audit_logs'
)
WHERE r.code IN ('REVIEWER', 'financial_auditor')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'create_reservation',
  'create_expense'
)
WHERE r.code = 'DATA_ENTRY'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'view_reports'
WHERE r.code = 'VIEWER'
ON CONFLICT DO NOTHING;

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

-- 008_backfill_financial_transaction_scope.sql
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

-- ============================================================
-- Source: database/migrations/009_suspend_monthly_fundings_restore_annual_allocation.sql
-- ============================================================

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


-- ============================================================
-- Source: database/migrations/012_release_partial_spent_reservation_remainder.sql
-- ============================================================

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

-- ============================================================
-- Source: database/migrations/015_fine_grained_permissions.sql
-- ============================================================

INSERT INTO permissions (code, name, description)
VALUES
  ('dashboard.view', 'عرض لوحة التحكم', 'السماح بعرض لوحة التحكم والملخصات'),
  ('alerts.view', 'عرض التنبيهات', 'السماح بعرض تنبيهات الأرصدة'),
  ('programs.view', 'عرض البرامج', 'السماح بعرض البرامج'),
  ('programs.add', 'إضافة برنامج', 'السماح بإضافة البرامج'),
  ('programs.edit', 'تعديل برنامج', 'السماح بتعديل البرامج'),
  ('programs.delete', 'حذف برنامج', 'السماح بحذف البرامج'),
  ('fiscal_years.view', 'عرض السنوات المالية', 'السماح بعرض السنوات المالية'),
  ('fiscal_years.add', 'إضافة سنة مالية', 'السماح بإضافة السنوات المالية'),
  ('fiscal_years.edit', 'تعديل سنة مالية', 'السماح بتعديل أو تفعيل السنوات المالية'),
  ('fiscal_years.delete', 'حذف سنة مالية', 'السماح بحذف السنوات المالية'),
  ('budget_types.view', 'عرض أنواع الميزانية', 'السماح بعرض أنواع الميزانية'),
  ('budget_types.add', 'إضافة نوع ميزانية', 'السماح بإضافة أنواع الميزانية'),
  ('budget_types.edit', 'تعديل نوع ميزانية', 'السماح بتعديل أنواع الميزانية'),
  ('budget_types.delete', 'حذف نوع ميزانية', 'السماح بحذف أنواع الميزانية'),
  ('budget_sections.view', 'عرض الأبواب', 'السماح بعرض الأبواب المالية'),
  ('budget_sections.add', 'إضافة باب', 'السماح بإضافة الأبواب المالية'),
  ('budget_sections.edit', 'تعديل باب', 'السماح بتعديل الأبواب المالية'),
  ('budget_sections.delete', 'حذف باب', 'السماح بحذف الأبواب المالية'),
  ('fundings.view', 'عرض التخصيصات', 'السماح بعرض التخصيصات'),
  ('fundings.add', 'إضافة تخصيص', 'السماح بإضافة التخصيصات'),
  ('fundings.edit', 'تعديل تخصيص', 'السماح بتعديل التخصيصات'),
  ('fundings.delete', 'حذف تخصيص', 'السماح بحذف التخصيصات'),
  ('reservations.view', 'عرض الحجوزات', 'السماح بعرض الحجوزات'),
  ('reservations.add', 'إضافة حجز', 'السماح بإضافة الحجوزات'),
  ('reservations.edit', 'تعديل حجز', 'السماح بتعديل الحجوزات'),
  ('reservations.delete', 'حذف حجز', 'السماح بحذف الحجوزات'),
  ('reservations.approve', 'اعتماد حجز', 'السماح باعتماد الحجوزات'),
  ('reservations.cancel', 'إلغاء حجز', 'السماح بإلغاء الحجوزات'),
  ('reservations.spend', 'صرف من حجز', 'السماح بإنشاء صرف من الحجز'),
  ('expenses.view', 'عرض الصرف', 'السماح بعرض المصروفات'),
  ('expenses.add', 'إضافة صرف', 'السماح بإضافة المصروفات'),
  ('expenses.cancel', 'إلغاء صرف', 'السماح بإلغاء المصروفات'),
  ('reports.view', 'عرض التقارير', 'السماح بعرض التقارير'),
  ('reports.print', 'طباعة التقارير', 'السماح بطباعة التقارير'),
  ('reports.export', 'تصدير التقارير', 'السماح بتصدير التقارير'),
  ('institution.view', 'عرض معلومات المؤسسة', 'السماح بعرض معلومات المؤسسة'),
  ('institution.edit', 'تعديل معلومات المؤسسة', 'السماح بتعديل معلومات المؤسسة'),
  ('users.view', 'عرض المستخدمين', 'السماح بعرض المستخدمين'),
  ('users.add', 'إضافة مستخدم', 'السماح بإضافة المستخدمين'),
  ('users.edit', 'تعديل مستخدم', 'السماح بتعديل المستخدمين وكلمات المرور'),
  ('audit_logs.view', 'عرض سجل الإجراءات', 'السماح بعرض سجل الإجراءات'),
  ('data_exchange.view', 'عرض الاستيراد والتصدير', 'السماح بفتح صفحة الاستيراد والتصدير'),
  ('data_exchange.import', 'استيراد بيانات', 'السماح باستيراد البيانات من Excel'),
  ('data_exchange.export', 'تصدير بيانات', 'السماح بتصدير البيانات إلى Excel'),
  ('backups.view', 'عرض النسخ الاحتياطي', 'السماح بعرض النسخ الاحتياطية'),
  ('backups.create', 'إنشاء نسخة احتياطية', 'السماح بإنشاء نسخة احتياطية'),
  ('backups.restore', 'استرجاع نسخة احتياطية', 'السماح باسترجاع نسخة احتياطية'),
  ('api_settings.view', 'عرض إعداد الاتصال', 'السماح بعرض إعدادات اتصال الخادم'),
  ('api_settings.edit', 'تعديل إعداد الاتصال', 'السماح بتعديل إعدادات اتصال الخادم')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE UPPER(r.code) IN ('SUPER_ADMIN', 'SUPERADMIN')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'manage_settings',
  'view_reports',
  'export_reports',
  'view_audit_logs',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'programs.add',
  'programs.edit',
  'fiscal_years.view',
  'fiscal_years.add',
  'fiscal_years.edit',
  'budget_types.view',
  'budget_types.add',
  'budget_types.edit',
  'budget_sections.view',
  'budget_sections.add',
  'budget_sections.edit',
  'fundings.view',
  'fundings.add',
  'fundings.edit',
  'reservations.view',
  'reservations.add',
  'reservations.edit',
  'reservations.approve',
  'reservations.cancel',
  'reservations.spend',
  'expenses.view',
  'expenses.add',
  'expenses.cancel',
  'reports.view',
  'reports.print',
  'reports.export',
  'institution.view',
  'institution.edit',
  'audit_logs.view',
  'data_exchange.view',
  'data_exchange.import',
  'data_exchange.export',
  'api_settings.view',
  'api_settings.edit'
)
WHERE UPPER(r.code) = 'ADMIN'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'view_reports',
  'export_reports',
  'view_audit_logs',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'fiscal_years.view',
  'budget_types.view',
  'budget_sections.view',
  'fundings.view',
  'reservations.view',
  'reservations.edit',
  'reservations.approve',
  'reservations.cancel',
  'reservations.spend',
  'expenses.view',
  'expenses.add',
  'expenses.cancel',
  'reports.view',
  'reports.print',
  'reports.export',
  'institution.view',
  'audit_logs.view',
  'api_settings.view'
)
WHERE UPPER(r.code) IN ('FINANCE_MANAGER', 'FINANCIAL_MANAGER', 'REVIEWER', 'FINANCIAL_AUDITOR')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'modify_records',
  'view_reports',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'programs.add',
  'programs.edit',
  'fiscal_years.view',
  'budget_sections.view',
  'budget_sections.add',
  'budget_sections.edit',
  'fundings.view',
  'reservations.view',
  'reservations.add',
  'reservations.edit',
  'expenses.view',
  'expenses.add',
  'reports.view',
  'institution.view',
  'api_settings.view'
)
WHERE UPPER(r.code) IN ('DATA_ENTRY', 'data_entry')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'view_records',
  'view_reports',
  'dashboard.view',
  'alerts.view',
  'programs.view',
  'fiscal_years.view',
  'budget_sections.view',
  'fundings.view',
  'reservations.view',
  'expenses.view',
  'reports.view',
  'institution.view',
  'api_settings.view'
)
WHERE UPPER(r.code) = 'VIEWER'
ON CONFLICT DO NOTHING;

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) NOT IN ('SUPER_ADMIN', 'SUPERADMIN')
  AND p.code IN (
    'delete_records',
    'manage_users',
    'manage_backups',
    'programs.delete',
    'fiscal_years.delete',
    'budget_types.delete',
    'budget_sections.delete',
    'fundings.delete',
    'reservations.delete',
    'users.view',
    'users.add',
    'users.edit',
    'backups.view',
    'backups.create',
    'backups.restore'
  );

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) NOT IN ('SUPER_ADMIN', 'SUPERADMIN', 'ADMIN')
  AND p.code IN (
    'data_exchange.view',
    'data_exchange.import',
    'data_exchange.export'
  );

DELETE FROM role_permissions rp
USING roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND UPPER(r.code) IN ('VIEWER', 'DATA_ENTRY')
  AND p.code IN (
    'view_audit_logs',
    'audit_logs.view',
    'export_reports',
    'reports.print',
    'reports.export'
  );

-- ============================================================
-- Source: database/migrations/016_document_attachments.sql
-- ============================================================

-- تعليق عربي: أرشفة مستندات الحجز والصرف كملفات محفوظة على الخادم مع سجل داخل قاعدة البيانات.
CREATE TABLE IF NOT EXISTS document_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(30) NOT NULL,
  entity_id UUID NOT NULL,
  original_file_name VARCHAR(300) NOT NULL,
  stored_file_name VARCHAR(300) NOT NULL,
  content_type VARCHAR(150) NOT NULL,
  file_size BIGINT NOT NULL CHECK (file_size > 0),
  storage_path TEXT NOT NULL,
  notes TEXT,
  uploaded_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES users(id),
  CONSTRAINT chk_document_attachments_entity_type
    CHECK (entity_type IN ('reservation', 'expense'))
);

CREATE INDEX IF NOT EXISTS idx_document_attachments_entity
  ON document_attachments(entity_type, entity_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_document_attachments_uploaded_by
  ON document_attachments(uploaded_by, created_at DESC)
  WHERE deleted_at IS NULL;

-- ============================================================
-- Source: database/migrations/017_deduplicate_roles.sql
-- ============================================================

-- تعليق عربي: توحيد الأدوار القديمة والجديدة حتى لا تظهر صلاحيات مكررة في واجهة المستخدمين.
INSERT INTO roles (code, name, description)
VALUES
  ('SUPER_ADMIN', 'سوبر أدمن', 'كل الصلاحيات مع الحذف وإدارة المستخدمين'),
  ('ADMIN', 'مدير نظام', 'إدارة النظام والاعتماد بدون صلاحية الحذف الحساسة'),
  ('FINANCE_MANAGER', 'مدير مالي', 'اعتماد الحجوزات والصرف والتقارير'),
  ('REVIEWER', 'مدقق مالي', 'مراجعة واعتماد العمليات المالية حسب الصلاحية'),
  ('DATA_ENTRY', 'إدخال بيانات', 'إدخال وتعديل البيانات التشغيلية بدون حذف حساس'),
  ('VIEWER', 'معاينة فقط', 'عرض البيانات بدون تعديل أو طباعة أو تصدير')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

WITH role_map AS (
  SELECT old_role.id AS old_role_id, new_role.id AS new_role_id
  FROM (
    VALUES
      ('super_admin', 'SUPER_ADMIN'),
      ('financial_manager', 'FINANCE_MANAGER'),
      ('financial_auditor', 'REVIEWER'),
      ('data_entry', 'DATA_ENTRY')
  ) AS pairs(old_code, new_code)
  JOIN roles old_role ON old_role.code = pairs.old_code
  JOIN roles new_role ON new_role.code = pairs.new_code
)
UPDATE users u
SET role_id = role_map.new_role_id,
    updated_at = NOW()
FROM role_map
WHERE u.role_id = role_map.old_role_id;

DELETE FROM role_permissions rp
USING roles r
WHERE rp.role_id = r.id
  AND r.code IN ('super_admin', 'financial_manager', 'financial_auditor', 'data_entry');

DELETE FROM roles
WHERE code IN ('super_admin', 'financial_manager', 'financial_auditor', 'data_entry');


COMMIT;

