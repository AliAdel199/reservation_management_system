# تنظيف بيانات التشغيل قبل الاستيراد

هذا المجلد يحتوي أدوات تنظيف قاعدة البيانات حتى تبدأ استيراد نظيف بدون بيانات تشغيل قديمة.

## ماذا يتم حذفه؟

- البرامج
- الأبواب
- التخصيصات السنوية القديمة
- التمويلات الشهرية القديمة
- الحجوزات
- المصروفات
- سجل الحركات المالية
- سجل الإجراءات

## ماذا يبقى؟

- المستخدمون
- الأدوار والصلاحيات
- السنوات المالية
- معلومات المؤسسة
- بنية الجداول والـ migrations

## التشغيل

يفضل إيقاف الـ API قبل التنظيف، ثم تشغيل الأمر من PowerShell:

```powershell
$env:DATABASE_URL = (Get-Content "D:\reservation_management_system\backend\.env" | Where-Object { $_ -like 'DATABASE_URL=*' }).Split('=', 2)[1]
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\database\maintenance\run-clear-business-data.ps1"
```

أو مباشرة عبر `psql`:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f "D:\reservation_management_system\database\maintenance\clear_business_data.sql"
```

خذ نسخة احتياطية قبل التشغيل إذا كانت قاعدة البيانات تحتوي بيانات مهمة.
