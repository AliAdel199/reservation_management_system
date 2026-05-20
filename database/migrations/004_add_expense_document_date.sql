-- تعليق عربي: تاريخ المستند يساعد في مطابقة الصرف مع الكتب/الوصولات الرسمية.
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS document_date DATE;
