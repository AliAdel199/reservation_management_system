# دليل تجهيز وتسليم نسخة الزبون

هذا الدليل مقسوم إلى قسمين:

- القسم الأول: إعدادات المطور وتجهيز ملفات التسليم عندك.
- القسم الثاني: تنصيب النسخة عند الزبون وتشغيل الـ API تلقائياً.

إذا كان الزبون يريد جهاز سيرفر مركزي وأجهزة فرعية ترتبط عليه عبر الشبكة،
راجع أيضاً الملف المختصر:

```text
D:\reservation_management_system\deploy\CUSTOMER_SERVER_CLIENT_SETUP.md
```

ولحماية النسخة من التشغيل على سيرفر غير مرخّص، راجع:

```text
D:\reservation_management_system\deploy\LICENSE_PROTECTION.md
```

نفترض أن مسار المشروع عندك وعند الزبون هو:

```text
D:\reservation_management_system
```

## آخر تحديثات نسخة التسليم

هذه النسخة تضيف وتثبت النقاط التالية:

- استيراد وتصدير Excel من داخل النظام.
- قالب Excel للحجوزات.
- استيراد الحجوزات عبر API مع إمكانية إرسالها للمراجعة أو اعتمادها حسب أعمدة الملف.
- تقرير Excel فعلي من صفحة التقارير.
- صفحة مخصصة باسم `استيراد/تصدير` داخل القائمة الجانبية.
- التمويل الشهري معلّق حالياً، والتخصيص المعتمد هو التخصيص السنوي للأبواب.
- حماية ترخيص اختيارية للـ API تربط التشغيل ببصمة جهاز السيرفر.
- صفحة Backup واسترجاع للسوبر أدمن مع سكربت نسخ احتياطي تلقائي عبر Windows Task Scheduler.

ملاحظة مهمة:

- هذه الإضافات لا تحتاج Migration جديد لقاعدة البيانات لأنها تستخدم الجداول الحالية والـ API الحالي.
- ملف SQL الموحد الموجود داخل `deploy\sql` محدث ويشمل migrations لحد `010_add_reservation_tracking_fields.sql`.
- بعد أي تعديل على Flutter أو Backend يجب إعادة تنفيذ أمر بناء نسخة التسليم حتى تتحدث ملفات `deploy\app` و `deploy\api`.

## القسم الأول: إعدادات المطور عندي

هذا القسم ينفذ على جهاز المطور فقط، قبل نسخ النظام إلى جهاز الزبون.

### 1. المتطلبات عند المطور

- Dart SDK مثبت.
- Flutter SDK مثبت ومجهز لـ Windows Desktop.
- المشروع موجود في `D:\reservation_management_system`.
- PowerShell متاح.

### 2. بناء نسخة التسليم

اختياري، وللتأكد قبل البناء يمكنك تنفيذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location 'D:\reservation_management_system'; flutter pub get"
```

الغرض من الأمر:

- تحميل مكتبات Flutter المطلوبة قبل البناء.
- مهم خصوصاً بعد إضافة مكتبات `excel` و `file_picker` الخاصة بالاستيراد والتصدير.
- سكربت بناء النسخة ينفذ هذا الأمر تلقائياً أيضاً، لذلك هذه الخطوة للتأكد فقط.

نفذ الأمر التالي من أي مكان في PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\build-customer-package.ps1" -ProjectRoot "D:\reservation_management_system"
```

الغرض من الأمر:

- يبني ملف الـ API التنفيذي داخل `D:\reservation_management_system\deploy\api\reservation_api.exe`.
- يبني نسخة Flutter Windows النهائية داخل `D:\reservation_management_system\deploy\app`.
- يجهز ملفات النسخة التي سيتم تسليمها للزبون.
- يستخدم رابط API الافتراضي `http://localhost:7070/api` داخل نسخة Flutter.
- يبني نسخة Flutter مع `--obfuscate` افتراضياً لتقليل قابلية قراءة الكود عند الهندسة العكسية.
- ملفات الرموز الخاصة بفك التتبع تحفظ عند المطور داخل `build\symbols\customer` ولا تُسلّم للزبون.
- يبني API الزبون مع `LICENSE_REQUIRED=true` افتراضياً، لذلك لا يمكن تعطيل الترخيص من ملف `.env` في نسخة التسليم.

بعد التنفيذ يجب التأكد من وجود الملفات التالية:

```text
D:\reservation_management_system\deploy\api\reservation_api.exe
D:\reservation_management_system\deploy\app\reservation_management_system.exe
D:\reservation_management_system\deploy\sql\001_customer_database_setup.sql
```

ملاحظة:

- لا تنسخ ملف `reservation_management_system.exe` وحده؛ لازم تنسخ مجلد `deploy\app` كاملاً لأن Flutter يحتاج ملفات `data` وملفات التشغيل المرافقة.

### 3. ملفات التسليم المطلوبة

انسخ مجلد `deploy` كاملاً إلى جهاز الزبون داخل:

```text
D:\reservation_management_system\deploy
```

ويجب أن يحتوي على:

```text
deploy\api\reservation_api.exe
deploy\app\reservation_management_system.exe
deploy\scripts
deploy\sql\001_customer_database_setup.sql
```

ملاحظة مهمة:

- لا تضع ملف `.env` النهائي داخل النسخة قبل معرفة كلمة مرور PostgreSQL عند الزبون.
- ملف `.env` يتم إنشاؤه على جهاز الزبون من خلال سكربت خاص.

### 4. تحديث نسخة زبون موجودة مسبقاً

إذا كان الزبون منصب النظام مسبقاً وتريد فقط تسليمه نسخة أحدث:

1. ابن النسخة من جديد عندك باستخدام أمر بناء نسخة التسليم.
2. انسخ مجلد `deploy` المحدث إلى جهاز الزبون فوق المجلد القديم.
3. شغل ملف SQL الموحد مرة ثانية إذا كانت النسخة الجديدة تحتوي تعديلات قاعدة بيانات.
4. أعد تشغيل مهمة الـ API حتى يقرأ الملفات الجديدة.

أوامر إعادة تشغيل الـ API عند الزبون:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

الغرض من الأوامر:

- توقف مراقبة وتشغيل الـ API مؤقتاً.
- تغلق نسخة الـ API القديمة إن كانت تعمل.
- تشغل الـ watchdog من جديد حتى يبدأ الـ API بالنسخة الجديدة.

## القسم الثاني: التسليم للزبون والإعدادات عنده

هذا القسم ينفذ على جهاز الزبون.

### 1. المتطلبات عند الزبون

- PostgreSQL مثبت على جهاز الزبون.
- معرفة كلمة مرور مستخدم PostgreSQL، غالباً المستخدم هو `postgres`.
- تشغيل PowerShell بصلاحية Administrator.
- وجود مجلد النظام في:

```text
D:\reservation_management_system
```

### 2. تجهيز قاعدة البيانات

نفذ الأمر التالي من PowerShell بصلاحية Administrator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE"
```

الغرض من الأمر:

- يتصل بـ PostgreSQL باستخدام مستخدم `postgres`.
- ينشئ قاعدة البيانات `reservation_management` إذا لم تكن موجودة.
- يشغل ملف SQL الموحد الذي يحتوي الجداول والعلاقات والبيانات الأساسية.
- يستخدم مرة واحدة غالباً عند تنصيب النظام على جهاز الزبون.
- يمكن تشغيله أيضاً عند تحديث نسخة الزبون إذا أضفنا migrations جديدة، لأن أغلب أوامر SQL مكتوبة بصيغة آمنة مثل `IF NOT EXISTS`.

استبدل `PASSWORD_HERE` بكلمة مرور PostgreSQL عند الزبون.

مثال:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "ali"
```

إذا كان `psql` غير معروف، استخدم الأمر التالي وحدد مسار `psql.exe`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -PsqlPath "C:\Program Files\PostgreSQL\16\bin\psql.exe"
```

الغرض من هذا الأمر:

- نفس أمر تجهيز قاعدة البيانات، لكن نحدد له مكان `psql.exe` يدوياً إذا لم يكن مضافاً إلى PATH.

### 3. إنشاء ملف إعداد API

بعد تجهيز قاعدة البيانات، نفذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\create-api-env.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -AdminUsername "admin" -AdminPassword "Admin@12345"
```

الغرض من الأمر:

- ينشئ ملف إعدادات الـ API باسم `.env`.
- يكتب رابط قاعدة البيانات `DATABASE_URL`.
- يولد `JWT_SECRET` قوي تلقائياً.
- يحدد منفذ التشغيل الافتراضي `7070`.
- يجهز حساب المدير الافتراضي للنظام.

سيتم إنشاء الملف:

```text
D:\reservation_management_system\deploy\api\.env
```

يمكن تغيير حساب المدير الافتراضي عند التنصيب:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\create-api-env.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -AdminUsername "admin" -AdminPassword "StrongPassword@123" -AdminFullName "System Administrator" -AdminEmail "admin@finance.local"
```

### 4. تشغيل API تلقائياً مع Windows

بعد وجود الملفات التالية:

```text
D:\reservation_management_system\deploy\api\reservation_api.exe
D:\reservation_management_system\deploy\api\.env
```

نفذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-api-autostart.ps1" -InstallRoot "D:\reservation_management_system\deploy"
```

الغرض من الأمر:

- ينشئ مهمة Windows Scheduled Task لتشغيل الـ API تلقائياً عند تشغيل الجهاز أو تسجيل الدخول.
- يشغل سكربت مراقبة `watchdog`.
- يعيد تشغيل الـ API تلقائياً إذا توقف أو فشل فحص الصحة.

هذا ينشئ Scheduled Task باسم:

```text
ReservationManagementAPI
```

والـ watchdog يفحص الرابط التالي:

```text
http://127.0.0.1:7070/health
```

إذا توقف الـ API أو فشل health check، يتم إعادة تشغيله تلقائياً.

ملاحظة:

- فحص `health` يتحقق من عمل الـ API ومن اتصال PostgreSQL أيضاً.
- إذا انقطع اتصال قاعدة البيانات ثم رجع، يحاول الـ API إعادة الاتصال تلقائياً.
- إذا بقي الاتصال فاشلاً، يعتبر الـ watchdog أن الخدمة غير سليمة ويحاول إعادة تشغيلها.

### 5. تشغيل البرنامج

بعد تشغيل الـ API تلقائياً، افتح تطبيق الزبون من:

```text
D:\reservation_management_system\deploy\app\reservation_management_system.exe
```

بيانات الدخول الافتراضية هي القيم التي تم تمريرها في أمر إنشاء `.env`.

### 6. تفعيل Backup تلقائي يومي

بعد إنشاء ملف `.env` وتشغيل قاعدة البيانات، فعّل النسخ الاحتياطي التلقائي من PowerShell بصلاحية Administrator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-backup-task.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DailyAt "02:00"
```

الغرض من الأمر:

- ينشئ Scheduled Task باسم `ReservationManagementDatabaseBackup`.
- يشغل `pg_dump` يومياً الساعة 02:00.
- يحفظ النسخ داخل `D:\reservation_management_system\deploy\api\backups` افتراضياً.
- يحذف النسخ الأقدم من عدد الأيام الموجود في `BACKUP_RETENTION_DAYS`.

تشغيل Backup يدوي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\run-database-backup.ps1" -ApiRoot "D:\reservation_management_system\deploy\api"
```

إذا لم يتعرف Windows على `pg_dump` أو `pg_restore`، افتح:

```text
D:\reservation_management_system\deploy\api\.env
```

واكتب المسارات الكاملة:

```text
PG_DUMP_PATH=C:\Program Files\PostgreSQL\16\bin\pg_dump.exe
PG_RESTORE_PATH=C:\Program Files\PostgreSQL\16\bin\pg_restore.exe
```

حذف مهمة النسخ التلقائي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\uninstall-backup-task.ps1"
```

### 7. إلغاء التشغيل التلقائي

إذا احتجت إيقاف خدمة الـ API وحذف مهمة التشغيل التلقائي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\uninstall-api-autostart.ps1"
```

الغرض من الأمر:

- يوقف مهمة التشغيل التلقائي `ReservationManagementAPI`.
- يحذف المهمة من Windows Task Scheduler.
- يوقف عملية `reservation_api.exe` إذا كانت تعمل.

### 8. إدارة تشغيل API بدون حذف التشغيل التلقائي

هذه الأوامر تستخدم إذا أردت إيقاف أو تشغيل أو إعادة تشغيل الـ API بدون حذف مهمة التشغيل التلقائي.

فحص حالة المهمة:

```powershell
Get-ScheduledTask -TaskName "ReservationManagementAPI"
```

الغرض من الأمر:

- يعرض هل مهمة تشغيل الـ API موجودة في Windows Task Scheduler.
- يفيد لمعرفة حالة المهمة قبل التشغيل أو الإيقاف.

إيقاف الـ API مؤقتاً:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
```

الغرض من الأمر:

- يوقف مهمة المراقبة `watchdog`.
- يوقف عملية `reservation_api.exe` الحالية.
- لا يحذف التشغيل التلقائي، لذلك يمكن تشغيله مرة ثانية لاحقاً.

تشغيل الـ API مرة ثانية:

```powershell
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

الغرض من الأمر:

- يشغل مهمة `ReservationManagementAPI`.
- المهمة ستشغل الـ watchdog، والـ watchdog سيشغل الـ API إذا لم يكن يعمل.

إعادة تشغيل الـ API:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

الغرض من الأمر:

- يستخدم بعد تعديل ملف `.env` مثل تغيير المنفذ أو كلمة مرور قاعدة البيانات.
- يوقف النسخة الحالية ثم يشغلها من جديد.

فحص صحة الـ API:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:7070/health" -UseBasicParsing
```

الغرض من الأمر:

- يتأكد أن الـ API يعمل ويرد على منفذ `7070`.
- يتأكد أن اتصال PostgreSQL يعمل من خلال فحص داخلي خفيف.
- إذا ظهر رد ناجح فهذا يعني أن التطبيق يستطيع الاتصال بالـ API.

عرض آخر سجلات التشغيل:

```powershell
Get-Content "D:\reservation_management_system\deploy\logs\reservation_api.out.log" -Tail 50
Get-Content "D:\reservation_management_system\deploy\logs\reservation_api.err.log" -Tail 50
```

الغرض من الأمر:

- يعرض آخر رسائل التشغيل والأخطاء.
- مفيد لمعرفة سبب توقف الـ API أو فشل الاتصال بقاعدة البيانات.

## ملاحظات مهمة

- ملف SQL الموحد موجود هنا:

```text
D:\reservation_management_system\deploy\sql\001_customer_database_setup.sql
```

- ملف SQL الحالي يشمل:

```text
001_initial_schema.sql
002_financial_foundation_upgrade.sql
003_fix_dashboard_remaining_formula.sql
004_add_expense_document_date.sql
005_fix_monthly_fundings_soft_delete_unique.sql
006_institution_settings.sql
006_make_monthly_fundings_program_level.sql
007_monthly_allocations_drive_total_allocation.sql
008_backfill_financial_transaction_scope.sql
009_suspend_monthly_fundings_restore_annual_allocation.sql
001_reference_data.sql
002_financial_foundation_data.sql
```

- ملفات Excel التي يصدرها النظام تحفظ غالباً داخل:

```text
%USERPROFILE%\Downloads\reservation_import_export
%USERPROFILE%\Downloads\reservation_reports
```

- بعد تغيير `PORT` داخل `.env` يجب إعادة تشغيل مهمة `ReservationManagementAPI`.
- لا تشغل أكثر من نسخة API على نفس المنفذ `7070`.
- إذا ظهر خطأ أن المنفذ مستخدم، فهذا يعني أن الـ API يعمل مسبقاً أو يوجد برنامج آخر يستخدم نفس المنفذ.
