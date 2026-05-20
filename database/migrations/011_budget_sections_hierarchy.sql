-- تعليق عربي: إضافة دعم الشجرة الهرمية للأبواب بدون خسارة البيانات الحالية.
-- كل الأبواب القديمة تتحول تلقائياً إلى أبواب نهائية Leaf قابلة للحجز والصرف.

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

-- تعليق عربي: الرمز صار فريداً داخل نفس الأب وليس داخل البرنامج كله،
-- حتى نقدر نكرر رمزاً فرعياً مثل 01 تحت أبواب مختلفة.
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
