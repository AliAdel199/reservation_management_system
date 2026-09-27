-- تعليق عربي: قفل السنة المالية بعد إغلاقها حتى لا تتغير أرقامها بعد اعتماد الحسابات الختامية.
-- القفل يُفرض داخل قاعدة البيانات بـ triggers، فيشمل الـ API والاستيراد وأي اتصال SQL مباشر.
-- رمز الخطأ FYLCK يحوله الخادم إلى رسالة عربية واضحة للمستخدم.

ALTER TABLE fiscal_years
  ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS locked_by UUID REFERENCES users(id);

INSERT INTO permissions (code, name, description)
VALUES (
  'fiscal_years.lock',
  'قفل وفتح السنة المالية',
  'السماح بقفل السنة المالية لمنع أي تعديل على بياناتها، وفتحها مرة أخرى'
)
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

-- تعليق عربي: مبدئياً للسوبر أدمن فقط، ويمكن منحها لغيره من شاشة المستخدمين.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'fiscal_years.lock'
WHERE UPPER(r.code) IN ('SUPER_ADMIN', 'SUPERADMIN')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION assert_fiscal_year_open(p_fiscal_year_id UUID)
RETURNS VOID AS $$
DECLARE
  v_year INTEGER;
BEGIN
  IF p_fiscal_year_id IS NULL THEN
    RETURN;
  END IF;

  SELECT year INTO v_year
  FROM fiscal_years
  WHERE id = p_fiscal_year_id AND is_locked;

  IF FOUND THEN
    RAISE EXCEPTION 'fiscal year % is locked', v_year
      USING ERRCODE = 'FYLCK';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- تعليق عربي: كثير من السجلات المنشأة عبر الـ API تترك fiscal_year_id فارغاً وتستمد سنتها من البرنامج
-- أو الباب أو الحجز، فنحدد السنة من أول رابط متوفر. نقرأ الصف كـ jsonb ليعمل نفس الكود على كل الجداول.
CREATE OR REPLACE FUNCTION resolve_row_fiscal_year(p_row JSONB)
RETURNS UUID AS $$
DECLARE
  v_fiscal_year_id UUID := NULLIF(p_row->>'fiscal_year_id', '')::uuid;
  v_section_id UUID := NULLIF(
    COALESCE(p_row->>'budget_section_id', p_row->>'section_id'), ''
  )::uuid;
  v_reservation_id UUID := NULLIF(p_row->>'reservation_id', '')::uuid;
BEGIN
  IF v_fiscal_year_id IS NULL AND p_row ? 'program_id' THEN
    SELECT fiscal_year_id INTO v_fiscal_year_id
    FROM programs WHERE id = NULLIF(p_row->>'program_id', '')::uuid;
  END IF;

  IF v_fiscal_year_id IS NULL AND v_section_id IS NOT NULL THEN
    SELECT COALESCE(bs.fiscal_year_id, p.fiscal_year_id) INTO v_fiscal_year_id
    FROM budget_sections bs
    LEFT JOIN programs p ON p.id = bs.program_id
    WHERE bs.id = v_section_id;
  END IF;

  IF v_fiscal_year_id IS NULL AND v_reservation_id IS NOT NULL THEN
    SELECT COALESCE(r.fiscal_year_id, p.fiscal_year_id) INTO v_fiscal_year_id
    FROM reservations r
    LEFT JOIN programs p ON p.id = r.program_id
    WHERE r.id = v_reservation_id;
  END IF;

  IF v_fiscal_year_id IS NULL AND NULLIF(p_row->>'fiscal_year', '') IS NOT NULL THEN
    SELECT id INTO v_fiscal_year_id
    FROM fiscal_years WHERE year = (p_row->>'fiscal_year')::integer;
  END IF;

  RETURN v_fiscal_year_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- تعليق عربي: عند التعديل نفحص الصف القديم والجديد حتى لا يُنقل سجل من سنة مقفلة أو إليها.
CREATE OR REPLACE FUNCTION enforce_fiscal_year_lock()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM assert_fiscal_year_open(resolve_row_fiscal_year(to_jsonb(OLD)));
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM assert_fiscal_year_open(resolve_row_fiscal_year(to_jsonb(NEW)));
    RETURN NEW;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- تعليق عربي: السنة المقفلة لا تُحذف ولا تتغير تواريخها أو رقمها؛ المسموح فقط تغيير القفل والتفعيل.
CREATE OR REPLACE FUNCTION enforce_locked_fiscal_year_row()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_locked THEN
      RAISE EXCEPTION 'fiscal year % is locked', OLD.year
        USING ERRCODE = 'FYLCK';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.is_locked AND NEW.is_locked AND (
    NEW.year IS DISTINCT FROM OLD.year OR
    NEW.name IS DISTINCT FROM OLD.name OR
    NEW.start_date IS DISTINCT FROM OLD.start_date OR
    NEW.end_date IS DISTINCT FROM OLD.end_date
  ) THEN
    RAISE EXCEPTION 'fiscal year % is locked', OLD.year
      USING ERRCODE = 'FYLCK';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  v_table TEXT;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'programs',
    'budget_sections',
    'fundings',
    'monthly_fundings',
    'reservations',
    'expenses',
    'financial_transactions'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_fiscal_year_lock ON %I', v_table, v_table);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_fiscal_year_lock
       BEFORE INSERT OR UPDATE OR DELETE ON %I
       FOR EACH ROW EXECUTE FUNCTION enforce_fiscal_year_lock()',
      v_table,
      v_table
    );
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS trg_fiscal_years_lock_guard ON fiscal_years;
CREATE TRIGGER trg_fiscal_years_lock_guard
BEFORE UPDATE OR DELETE ON fiscal_years
FOR EACH ROW
EXECUTE FUNCTION enforce_locked_fiscal_year_row();
