-- تعليق عربي: إضافة حقول متابعة الحجز المطابقة لسجل Excel الحكومي.
-- الجهة والقسم والهاتف تساعد في معرفة صاحب الطلب، وملاحظة التنفيذ تحفظ ملاحظات إنجاز الحجز.
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS execution_note TEXT,
  ADD COLUMN IF NOT EXISTS requester_department VARCHAR(250),
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(100);

-- تعليق عربي: ننسخ العنوان القديم كجهة عند السجلات القديمة فقط إذا كان حقل الجهة فارغاً.
UPDATE reservations
SET beneficiary = COALESCE(NULLIF(beneficiary, ''), title)
WHERE beneficiary IS NULL OR beneficiary = '';

CREATE INDEX IF NOT EXISTS idx_reservations_beneficiary
  ON reservations(LOWER(beneficiary));

CREATE INDEX IF NOT EXISTS idx_reservations_requester_department
  ON reservations(LOWER(requester_department));
