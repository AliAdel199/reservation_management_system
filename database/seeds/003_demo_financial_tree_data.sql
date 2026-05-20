SET client_encoding = 'UTF8';

-- تعليق عربي: بيانات تجريبية كاملة بعد تنظيف بيانات التشغيل.
-- يشمل: سنة مالية، برامج، شجرة أبواب هرمية، تخصيصات سنوية، حجوزات، صرف، وحركات Ledger.
-- يمكن تشغيله بعد:
-- psql -h localhost -U postgres -d reservation_management -f database/maintenance/clear_business_data.sql

BEGIN;

DO $$
DECLARE
  v_admin_id UUID;
  v_fiscal_year_id UUID;
  v_operational_type_id UUID;
  v_oncology_type_id UUID;
  v_special_type_id UUID;

  v_operational_program_id UUID := '10000000-0000-0000-0000-000000000001';
  v_oncology_program_id UUID := '10000000-0000-0000-0000-000000000002';
  v_special_program_id UUID := '10000000-0000-0000-0000-000000000003';

  v_sec_expenses UUID := '20000000-0000-0000-0000-000000000001';
  v_sec_compensation UUID := '20000000-0000-0000-0000-000000000002';
  v_sec_salaries_group UUID := '20000000-0000-0000-0000-000000000003';
  v_sec_permanent_salaries UUID := '20000000-0000-0000-0000-000000000004';
  v_sec_temp_wages UUID := '20000000-0000-0000-0000-000000000005';
  v_sec_supplies UUID := '20000000-0000-0000-0000-000000000006';
  v_sec_fuel UUID := '20000000-0000-0000-0000-000000000007';
  v_sec_stationery UUID := '20000000-0000-0000-0000-000000000008';
  v_sec_cleaning UUID := '20000000-0000-0000-0000-000000000009';
  v_sec_services UUID := '20000000-0000-0000-0000-000000000010';
  v_sec_electricity UUID := '20000000-0000-0000-0000-000000000011';
  v_sec_building_maintenance UUID := '20000000-0000-0000-0000-000000000012';

  v_sec_treatment_program UUID := '30000000-0000-0000-0000-000000000001';
  v_sec_medicines_group UUID := '30000000-0000-0000-0000-000000000002';
  v_sec_oncology_medicines UUID := '30000000-0000-0000-0000-000000000003';
  v_sec_lab_supplies UUID := '30000000-0000-0000-0000-000000000004';
  v_sec_devices_group UUID := '30000000-0000-0000-0000-000000000005';
  v_sec_device_maintenance UUID := '30000000-0000-0000-0000-000000000006';

  v_sec_special_root UUID := '40000000-0000-0000-0000-000000000001';
  v_sec_training UUID := '40000000-0000-0000-0000-000000000002';

  v_res_001 UUID := '50000000-0000-0000-0000-000000000001';
  v_res_002 UUID := '50000000-0000-0000-0000-000000000002';
  v_res_003 UUID := '50000000-0000-0000-0000-000000000003';
  v_res_004 UUID := '50000000-0000-0000-0000-000000000004';
  v_res_005 UUID := '50000000-0000-0000-0000-000000000005';

  v_exp_001 UUID := '60000000-0000-0000-0000-000000000001';
  v_exp_002 UUID := '60000000-0000-0000-0000-000000000002';
  v_exp_003 UUID := '60000000-0000-0000-0000-000000000003';
BEGIN
  SELECT id INTO v_admin_id
  FROM users
  ORDER BY created_at
  LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'لا يوجد مستخدم في النظام. شغّل الـ API مرة واحدة حتى ينشئ حساب المدير الافتراضي، ثم أعد تشغيل هذا الملف.';
  END IF;

  INSERT INTO fiscal_years (year, name, start_date, end_date, is_active)
  VALUES (2026, 'السنة المالية 2026', DATE '2026-01-01', DATE '2026-12-31', TRUE)
  ON CONFLICT (year) DO UPDATE
  SET name = EXCLUDED.name,
      start_date = EXCLUDED.start_date,
      end_date = EXCLUDED.end_date,
      is_active = TRUE,
      updated_at = NOW()
  RETURNING id INTO v_fiscal_year_id;

  INSERT INTO budget_types (code, name, description)
  VALUES
    ('OPERATIONAL', 'تشغيلية', 'ميزانية تشغيلية عامة'),
    ('GOV_ONCOLOGY', 'برنامج حكومي أورام', 'ميزانية البرنامج الحكومي للأورام'),
    ('SPECIAL_PROGRAMS', 'برامج خاصة', 'ميزانيات البرامج الخاصة')
  ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      updated_at = NOW();

  SELECT id INTO v_operational_type_id FROM budget_types WHERE code = 'OPERATIONAL';
  SELECT id INTO v_oncology_type_id FROM budget_types WHERE code = 'GOV_ONCOLOGY';
  SELECT id INTO v_special_type_id FROM budget_types WHERE code = 'SPECIAL_PROGRAMS';

  -- تعليق عربي: حذف بيانات Demo السابقة فقط، بدون لمس بيانات المستخدم الحقيقية.
  DELETE FROM financial_transactions WHERE transaction_number LIKE 'DEMO-%';
  DELETE FROM expenses WHERE id IN (v_exp_001, v_exp_002, v_exp_003);
  DELETE FROM reservations WHERE id IN (v_res_001, v_res_002, v_res_003, v_res_004, v_res_005);
  DELETE FROM fundings WHERE funding_reference LIKE 'DEMO-FUND-%';
  DELETE FROM budget_sections
  WHERE id IN (
    v_sec_expenses, v_sec_compensation, v_sec_salaries_group, v_sec_permanent_salaries,
    v_sec_temp_wages, v_sec_supplies, v_sec_fuel, v_sec_stationery, v_sec_cleaning,
    v_sec_services, v_sec_electricity, v_sec_building_maintenance,
    v_sec_treatment_program, v_sec_medicines_group, v_sec_oncology_medicines,
    v_sec_lab_supplies, v_sec_devices_group, v_sec_device_maintenance,
    v_sec_special_root, v_sec_training
  );
  DELETE FROM programs WHERE id IN (v_operational_program_id, v_oncology_program_id, v_special_program_id);

  INSERT INTO programs (id, code, name, description, fiscal_year, fiscal_year_id, is_active, created_by)
  VALUES
    (v_operational_program_id, '01', 'التشغيلية', 'برنامج تجريبي للمصروفات التشغيلية العامة', 2026, v_fiscal_year_id, TRUE, v_admin_id),
    (v_oncology_program_id, '02', 'برنامج حكومي أورام', 'برنامج تجريبي للأدوية والمستلزمات الطبية', 2026, v_fiscal_year_id, TRUE, v_admin_id),
    (v_special_program_id, '03', 'برامج خاصة', 'برنامج تجريبي للتدريب والتطوير', 2026, v_fiscal_year_id, TRUE, v_admin_id);

  -- تعليق عربي: الأبواب التجميعية غير قابلة للحجز، والأبواب النهائية فقط تحمل التخصيص السنوي.
  INSERT INTO budget_sections (
    id, program_id, fiscal_year_id, budget_type_id, parent_id, level, full_code,
    is_postable, sort_order, path, code, name, description, allocated_amount,
    is_active, created_by
  )
  VALUES
    (v_sec_expenses, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, NULL, 1, '02', FALSE, 1, v_sec_expenses::text, '02', 'نفقات', 'باب تجميعي رئيسي', 0, TRUE, v_admin_id),
    (v_sec_compensation, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_expenses, 2, '0201', FALSE, 1, v_sec_expenses::text || '/' || v_sec_compensation::text, '01', 'تعويضات الموظفين', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_salaries_group, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_compensation, 3, '020101', FALSE, 1, v_sec_expenses::text || '/' || v_sec_compensation::text || '/' || v_sec_salaries_group::text, '01', 'رواتب وأجور', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_permanent_salaries, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_salaries_group, 4, '02010101', TRUE, 1, v_sec_expenses::text || '/' || v_sec_compensation::text || '/' || v_sec_salaries_group::text || '/' || v_sec_permanent_salaries::text, '01', 'رواتب دائمة', 'باب نهائي قابل للتخصيص والحجز', 12000000, TRUE, v_admin_id),
    (v_sec_temp_wages, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_salaries_group, 4, '02010102', TRUE, 2, v_sec_expenses::text || '/' || v_sec_compensation::text || '/' || v_sec_salaries_group::text || '/' || v_sec_temp_wages::text, '02', 'أجور مؤقتين', 'باب نهائي قابل للتخصيص والحجز', 3000000, TRUE, v_admin_id),
    (v_sec_supplies, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_expenses, 2, '0202', FALSE, 2, v_sec_expenses::text || '/' || v_sec_supplies::text, '02', 'مستلزمات سلعية', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_fuel, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_supplies, 3, '020201', TRUE, 1, v_sec_expenses::text || '/' || v_sec_supplies::text || '/' || v_sec_fuel::text, '01', 'وقود', 'باب نهائي قابل للتخصيص والحجز', 5000000, TRUE, v_admin_id),
    (v_sec_stationery, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_supplies, 3, '020202', TRUE, 2, v_sec_expenses::text || '/' || v_sec_supplies::text || '/' || v_sec_stationery::text, '02', 'قرطاسية', 'باب نهائي قابل للتخصيص والحجز', 1200000, TRUE, v_admin_id),
    (v_sec_cleaning, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_supplies, 3, '020203', TRUE, 3, v_sec_expenses::text || '/' || v_sec_supplies::text || '/' || v_sec_cleaning::text, '03', 'مواد تنظيف', 'باب نهائي قابل للتخصيص والحجز', 900000, TRUE, v_admin_id),
    (v_sec_services, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_expenses, 2, '0203', FALSE, 3, v_sec_expenses::text || '/' || v_sec_services::text, '03', 'خدمات', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_electricity, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_services, 3, '020301', TRUE, 1, v_sec_expenses::text || '/' || v_sec_services::text || '/' || v_sec_electricity::text, '01', 'كهرباء', 'باب نهائي قابل للتخصيص والحجز', 2500000, TRUE, v_admin_id),
    (v_sec_building_maintenance, v_operational_program_id, v_fiscal_year_id, v_operational_type_id, v_sec_services, 3, '020302', TRUE, 2, v_sec_expenses::text || '/' || v_sec_services::text || '/' || v_sec_building_maintenance::text, '02', 'صيانة مباني', 'باب نهائي قابل للتخصيص والحجز', 4000000, TRUE, v_admin_id),

    (v_sec_treatment_program, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, NULL, 1, '03', FALSE, 1, v_sec_treatment_program::text, '03', 'برامج علاجية', 'باب تجميعي لبرنامج الأورام', 0, TRUE, v_admin_id),
    (v_sec_medicines_group, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, v_sec_treatment_program, 2, '0301', FALSE, 1, v_sec_treatment_program::text || '/' || v_sec_medicines_group::text, '01', 'أدوية', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_oncology_medicines, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, v_sec_medicines_group, 3, '030101', TRUE, 1, v_sec_treatment_program::text || '/' || v_sec_medicines_group::text || '/' || v_sec_oncology_medicines::text, '01', 'أدوية أورام', 'باب نهائي قابل للتخصيص والحجز', 18000000, TRUE, v_admin_id),
    (v_sec_lab_supplies, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, v_sec_medicines_group, 3, '030102', TRUE, 2, v_sec_treatment_program::text || '/' || v_sec_medicines_group::text || '/' || v_sec_lab_supplies::text, '02', 'مستلزمات مختبر', 'باب نهائي قابل للتخصيص والحجز', 6000000, TRUE, v_admin_id),
    (v_sec_devices_group, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, v_sec_treatment_program, 2, '0302', FALSE, 2, v_sec_treatment_program::text || '/' || v_sec_devices_group::text, '02', 'أجهزة وصيانة', 'تجميعي', 0, TRUE, v_admin_id),
    (v_sec_device_maintenance, v_oncology_program_id, v_fiscal_year_id, v_oncology_type_id, v_sec_devices_group, 3, '030201', TRUE, 1, v_sec_treatment_program::text || '/' || v_sec_devices_group::text || '/' || v_sec_device_maintenance::text, '01', 'صيانة أجهزة', 'باب نهائي قابل للتخصيص والحجز', 3500000, TRUE, v_admin_id),

    (v_sec_special_root, v_special_program_id, v_fiscal_year_id, v_special_type_id, NULL, 1, '04', FALSE, 1, v_sec_special_root::text, '04', 'برامج خاصة', 'باب تجميعي للبرامج الخاصة', 0, TRUE, v_admin_id),
    (v_sec_training, v_special_program_id, v_fiscal_year_id, v_special_type_id, v_sec_special_root, 2, '0401', TRUE, 1, v_sec_special_root::text || '/' || v_sec_training::text, '01', 'تدريب وتطوير', 'باب نهائي قابل للتخصيص والحجز', 2000000, TRUE, v_admin_id);

  INSERT INTO fundings (
    id, program_id, budget_section_id, funding_reference, fiscal_year,
    fiscal_year_id, budget_type_id, allocated_amount, notes, created_by
  )
  SELECT
    gen_random_uuid(),
    bs.program_id,
    bs.id,
    'DEMO-FUND-' || bs.full_code,
    2026,
    bs.fiscal_year_id,
    bs.budget_type_id,
    bs.allocated_amount,
    'تخصيص سنوي تجريبي للباب ' || bs.full_code,
    v_admin_id
  FROM budget_sections bs
  WHERE bs.is_postable = TRUE
    AND bs.allocated_amount > 0
    AND bs.id IN (
      v_sec_permanent_salaries, v_sec_temp_wages, v_sec_fuel, v_sec_stationery,
      v_sec_cleaning, v_sec_electricity, v_sec_building_maintenance,
      v_sec_oncology_medicines, v_sec_lab_supplies, v_sec_device_maintenance,
      v_sec_training
    );

  INSERT INTO financial_transactions (
    transaction_number, transaction_type, amount, transaction_date, direction,
    description, reference_table, reference_type, reference_id, program_id,
    budget_section_id, section_id, fiscal_year_id, budget_type_id, funding_id,
    created_by
  )
  SELECT
    'DEMO-ALLOC-' || bs.full_code,
    'allocation'::transaction_type,
    bs.allocated_amount,
    TIMESTAMPTZ '2026-01-01 09:00:00+03',
    'IN'::transaction_direction,
    'تخصيص سنوي تجريبي للباب ' || bs.full_code,
    'fundings',
    'fundings',
    f.id,
    bs.program_id,
    bs.id,
    bs.id,
    bs.fiscal_year_id,
    bs.budget_type_id,
    f.id,
    v_admin_id
  FROM budget_sections bs
  JOIN fundings f ON f.budget_section_id = bs.id
  WHERE f.funding_reference LIKE 'DEMO-FUND-%';

  INSERT INTO reservations (
    id, reservation_number, program_id, budget_section_id, funding_id,
    fiscal_year_id, budget_type_id, title, description, beneficiary, subject,
    requester_department, contact_phone, execution_note, reserved_amount,
    workflow_status, reservation_date, approved_by, approved_at, cancelled_by,
    cancelled_at, cancel_reason, created_by, updated_by
  )
  VALUES
    (
      v_res_001, 'DEMO-RES-001', v_operational_program_id, v_sec_fuel,
      (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020201'),
      v_fiscal_year_id, v_operational_type_id, 'شراء وقود للمولدات', 'حجز بانتظار الاعتماد',
      'قسم الخدمات', 'شراء وقود للمولدات', 'قسم الخدمات', '07700000001', 'بانتظار الاعتماد',
      250000, 'under_review', DATE '2026-02-05', NULL, NULL, NULL, NULL, NULL, v_admin_id, v_admin_id
    ),
    (
      v_res_002, 'DEMO-RES-002', v_operational_program_id, v_sec_stationery,
      (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020202'),
      v_fiscal_year_id, v_operational_type_id, 'تجهيز قرطاسية شهرية', 'حجز معتمد غير مصروف',
      'المخزن المركزي', 'تجهيز قرطاسية شهرية', 'المخزن المركزي', '07700000002', 'تم الاعتماد',
      600000, 'approved', DATE '2026-02-12', v_admin_id, TIMESTAMPTZ '2026-02-13 10:00:00+03', NULL, NULL, NULL, v_admin_id, v_admin_id
    ),
    (
      v_res_003, 'DEMO-RES-003', v_operational_program_id, v_sec_cleaning,
      (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020203'),
      v_fiscal_year_id, v_operational_type_id, 'مواد تنظيف للأقسام', 'حجز مصروف بالكامل',
      'شعبة الخدمات', 'مواد تنظيف للأقسام', 'شعبة الخدمات', '07700000003', 'تم الصرف بالكامل',
      500000, 'completed', DATE '2026-03-10', v_admin_id, TIMESTAMPTZ '2026-03-11 11:00:00+03', NULL, NULL, NULL, v_admin_id, v_admin_id
    ),
    (
      v_res_004, 'DEMO-RES-004', v_oncology_program_id, v_sec_oncology_medicines,
      (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-030101'),
      v_fiscal_year_id, v_oncology_type_id, 'طلب أدوية ملغي', 'حجز ملغي للأرشفة فقط',
      'مركز الأورام', 'طلب أدوية ملغي', 'مركز الأورام', '07700000004', 'ألغي قبل الاعتماد',
      1200000, 'cancelled', DATE '2026-04-03', NULL, NULL, v_admin_id, TIMESTAMPTZ '2026-04-04 12:00:00+03', 'طلب تجريبي ملغي', v_admin_id, v_admin_id
    ),
    (
      v_res_005, 'DEMO-RES-005', v_oncology_program_id, v_sec_lab_supplies,
      (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-030102'),
      v_fiscal_year_id, v_oncology_type_id, 'مستلزمات مختبر عاجلة', 'حجز معتمد مع صرف جزئي',
      'مختبر الأورام', 'مستلزمات مختبر عاجلة', 'مختبر الأورام', '07700000005', 'صرف جزئي',
      1500000, 'approved', DATE '2026-04-18', v_admin_id, TIMESTAMPTZ '2026-04-19 09:30:00+03', NULL, NULL, NULL, v_admin_id, v_admin_id
    );

  INSERT INTO financial_transactions (
    transaction_number, transaction_type, amount, transaction_date, direction,
    description, reference_table, reference_type, reference_id, program_id,
    budget_section_id, section_id, fiscal_year_id, budget_type_id, funding_id,
    reservation_id, created_by
  )
  VALUES
    ('DEMO-RES-HOLD-002', 'reservation_hold', 600000, TIMESTAMPTZ '2026-02-13 10:00:00+03', 'OUT', 'حجز معتمد DEMO-RES-002', 'reservations', 'reservations', v_res_002, v_operational_program_id, v_sec_stationery, v_sec_stationery, v_fiscal_year_id, v_operational_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020202'), v_res_002, v_admin_id),
    ('DEMO-RES-HOLD-003', 'reservation_hold', 500000, TIMESTAMPTZ '2026-03-11 11:00:00+03', 'OUT', 'حجز معتمد DEMO-RES-003', 'reservations', 'reservations', v_res_003, v_operational_program_id, v_sec_cleaning, v_sec_cleaning, v_fiscal_year_id, v_operational_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020203'), v_res_003, v_admin_id),
    ('DEMO-RES-HOLD-005', 'reservation_hold', 1500000, TIMESTAMPTZ '2026-04-19 09:30:00+03', 'OUT', 'حجز معتمد DEMO-RES-005', 'reservations', 'reservations', v_res_005, v_oncology_program_id, v_sec_lab_supplies, v_sec_lab_supplies, v_fiscal_year_id, v_oncology_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-030102'), v_res_005, v_admin_id);

  INSERT INTO expenses (
    id, reservation_id, expense_number, amount, expense_status, expense_date,
    beneficiary_name, payment_method, document_number, document_date,
    description, notes, created_by, approved_by
  )
  VALUES
    (v_exp_001, v_res_003, 'DEMO-EXP-001', 350000, 'paid', DATE '2026-03-15', 'شركة تجهيزات النظافة', 'تحويل مصرفي', 'DOC-2026-001', DATE '2026-03-14', 'صرف أول لمواد التنظيف', 'صرف تجريبي', v_admin_id, v_admin_id),
    (v_exp_002, v_res_003, 'DEMO-EXP-002', 150000, 'paid', DATE '2026-03-20', 'شركة تجهيزات النظافة', 'نقدي', 'DOC-2026-002', DATE '2026-03-19', 'إكمال صرف مواد التنظيف', 'صرف تجريبي', v_admin_id, v_admin_id),
    (v_exp_003, v_res_005, 'DEMO-EXP-003', 400000, 'paid', DATE '2026-04-25', 'شركة مستلزمات المختبر', 'صك', 'DOC-2026-003', DATE '2026-04-24', 'صرف جزئي لمستلزمات المختبر', 'صرف تجريبي', v_admin_id, v_admin_id);

  INSERT INTO financial_transactions (
    transaction_number, transaction_type, amount, transaction_date, direction,
    description, reference_table, reference_type, reference_id, program_id,
    budget_section_id, section_id, fiscal_year_id, budget_type_id, funding_id,
    reservation_id, expense_id, created_by
  )
  VALUES
    ('DEMO-EXP-DISB-001', 'expense_disbursement', 350000, TIMESTAMPTZ '2026-03-15 12:00:00+03', 'OUT', 'صرف DEMO-EXP-001', 'expenses', 'expenses', v_exp_001, v_operational_program_id, v_sec_cleaning, v_sec_cleaning, v_fiscal_year_id, v_operational_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020203'), v_res_003, v_exp_001, v_admin_id),
    ('DEMO-EXP-DISB-002', 'expense_disbursement', 150000, TIMESTAMPTZ '2026-03-20 12:00:00+03', 'OUT', 'صرف DEMO-EXP-002', 'expenses', 'expenses', v_exp_002, v_operational_program_id, v_sec_cleaning, v_sec_cleaning, v_fiscal_year_id, v_operational_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-020203'), v_res_003, v_exp_002, v_admin_id),
    ('DEMO-EXP-DISB-003', 'expense_disbursement', 400000, TIMESTAMPTZ '2026-04-25 12:00:00+03', 'OUT', 'صرف DEMO-EXP-003', 'expenses', 'expenses', v_exp_003, v_oncology_program_id, v_sec_lab_supplies, v_sec_lab_supplies, v_fiscal_year_id, v_oncology_type_id, (SELECT id FROM fundings WHERE funding_reference = 'DEMO-FUND-030102'), v_res_005, v_exp_003, v_admin_id);

  INSERT INTO audit_logs (action, entity_name, entity_type, description, created_by, new_values)
  VALUES (
    'DEMO_SEED',
    'system',
    'system',
    'إنشاء بيانات تجريبية مالية تشمل البرامج، شجرة الأبواب، الحجوزات، الصرف، والسجل المالي.',
    v_admin_id,
    jsonb_build_object(
      'fiscal_year', 2026,
      'programs', 3,
      'postable_sections', 11,
      'reservations', 5,
      'expenses', 3
    )
  );
END $$;

COMMIT;

SELECT 'programs' AS table_name, COUNT(*) AS rows_count FROM programs WHERE deleted_at IS NULL
UNION ALL SELECT 'budget_sections', COUNT(*) FROM budget_sections WHERE deleted_at IS NULL
UNION ALL SELECT 'fundings', COUNT(*) FROM fundings WHERE deleted_at IS NULL
UNION ALL SELECT 'reservations', COUNT(*) FROM reservations WHERE deleted_at IS NULL
UNION ALL SELECT 'expenses', COUNT(*) FROM expenses WHERE deleted_at IS NULL
UNION ALL SELECT 'financial_transactions', COUNT(*) FROM financial_transactions
ORDER BY table_name;
