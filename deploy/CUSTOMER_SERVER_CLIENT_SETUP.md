# دليل تنصيب النظام عند الزبون: سيرفر + أجهزة فرعية

هذا الملف يشرح شنو الملفات التي نأخذها للزبون، شنو ينصب على جهاز السيرفر، وشنو ينصب على الأجهزة الفرعية.

نفترض أن مسار النظام عند الزبون هو:

```text
D:\reservation_management_system
```

## 1. فكرة التشغيل

النظام يتكون من 3 أجزاء:

- قاعدة البيانات PostgreSQL: تنصب على جهاز السيرفر فقط.
- خدمة API: تنصب على جهاز السيرفر فقط وتشتغل تلقائياً مع Windows.
- تطبيق Windows: ينسخ على جهاز السيرفر وعلى كل جهاز فرعي يحتاج يستخدم النظام.

الأجهزة الفرعية لا تحتاج قاعدة بيانات ولا API. فقط تحتاج ملف التطبيق وتكتب IP السيرفر من صفحة `إعداد الاتصال`.

## 2. الملفات التي نأخذها للزبون

انسخ مجلد `deploy` كاملاً:

```text
D:\reservation_management_system\deploy
```

المجلد يجب أن يحتوي:

```text
deploy\api\reservation_api.exe
deploy\app\reservation_management_system.exe
deploy\app\data
deploy\app\flutter_windows.dll
deploy\scripts
deploy\sql\001_customer_database_setup.sql
deploy\README_CUSTOMER_INSTALL.md
deploy\CUSTOMER_SERVER_CLIENT_SETUP.md
deploy\LICENSE_PROTECTION.md
```

مهم:

- لا تنسخ `reservation_management_system.exe` وحده.
- لازم تنسخ مجلد `deploy\app` كاملاً لأن تطبيق Flutter يحتاج ملفات `data`.
- ملف `.env` لا ينسخ جاهز عادة، ينشأ عند الزبون حسب كلمة مرور قاعدة البيانات.

## 3. تجهيز جهاز السيرفر

نفذ هذه الخطوات على جهاز السيرفر فقط.

### 3.1 تثبيت PostgreSQL

ثبت PostgreSQL على السيرفر واحفظ كلمة مرور المستخدم `postgres`.

يفضل أن تكون قاعدة البيانات على نفس السيرفر الذي يشغل الـ API.

### 3.2 نسخ ملفات النظام

ضع الملفات بهذا الشكل:

```text
D:\reservation_management_system\deploy
```

### 3.3 إنشاء قاعدة البيانات وتشغيل SQL

افتح PowerShell بصلاحية Administrator ونفذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE"
```

استبدل `PASSWORD_HERE` بكلمة مرور PostgreSQL.

إذا كان `psql` غير معروف:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -PsqlPath "C:\Program Files\PostgreSQL\16\bin\psql.exe"
```

### 3.4 إنشاء ملف إعدادات API

نفذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\create-api-env.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -AdminUsername "admin" -AdminPassword "Admin@12345"
```

هذا ينشئ الملف:

```text
D:\reservation_management_system\deploy\api\.env
```

ملاحظات:

- `HOST=0.0.0.0` يعني الـ API يقبل اتصال من باقي الأجهزة داخل الشبكة.
- `PORT=7070` هو المنفذ الافتراضي.
- يمكن تغيير كلمة مرور المدير الافتراضي من نفس الأمر.

### 3.5 تفعيل حماية الترخيص

قبل التشغيل النهائي عند الزبون، إذا تريد تمنع نسخ النظام إلى سيرفر آخر، فعّل الترخيص حسب ملف:

```text
D:\reservation_management_system\deploy\LICENSE_PROTECTION.md
```

الملخص السريع:

- استخرج بصمة السيرفر من `deploy\scripts\get-server-fingerprint.ps1`.
- أنشئ `license.json` عندك باستخدام المفتاح الخاص.
- انسخ `license.json` و `license_public.pem` إلى `deploy\api`.
- غيّر `LICENSE_ENFORCEMENT=true` داخل `deploy\api\.env`.

### 3.6 تشغيل API تلقائياً مع Windows

نفذ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-api-autostart.ps1" -InstallRoot "D:\reservation_management_system\deploy"
```

هذا ينشئ Scheduled Task باسم:

```text
ReservationManagementAPI
```

الخدمة تستخدم watchdog، يعني إذا توقف الـ API يحاول يشغله مرة ثانية تلقائياً.

### 3.7 فتح منفذ API في Windows Firewall

حتى الأجهزة الفرعية تقدر تتصل بالسيرفر، افتح منفذ `7070`:

```powershell
New-NetFirewallRule -DisplayName "Reservation Management API 7070" -Direction Inbound -Protocol TCP -LocalPort 7070 -Action Allow
```

الغرض:

- يسمح للأجهزة داخل الشبكة بالوصول إلى API على السيرفر.

### 3.8 معرفة IP السيرفر

على السيرفر نفذ:

```powershell
ipconfig
```

خذ قيمة IPv4، مثال:

```text
192.168.1.10
```

يفضل تثبيت IP السيرفر من إعدادات الشبكة أو من الراوتر حتى لا يتغير بعد إعادة التشغيل.

### 3.9 اختبار API على السيرفر

نفذ:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:7070/health" -UseBasicParsing
```

إذا رجع رد ناجح، جرّب من جهاز فرعي داخل نفس الشبكة:

```powershell
Invoke-WebRequest -Uri "http://192.168.1.10:7070/health" -UseBasicParsing
```

استبدل `192.168.1.10` بـ IP السيرفر الحقيقي.

## 4. تجهيز الأجهزة الفرعية

نفذ هذه الخطوات على كل جهاز مستخدم.

### 4.1 نسخ تطبيق Windows فقط

انسخ مجلد التطبيق:

```text
D:\reservation_management_system\deploy\app
```

على الجهاز الفرعي يكفي وجود:

```text
D:\reservation_management_system\deploy\app\reservation_management_system.exe
D:\reservation_management_system\deploy\app\data
D:\reservation_management_system\deploy\app\flutter_windows.dll
```

الأجهزة الفرعية لا تحتاج:

```text
deploy\api
deploy\sql
PostgreSQL
```

### 4.2 إعداد الاتصال بالسيرفر

افتح التطبيق من:

```text
D:\reservation_management_system\deploy\app\reservation_management_system.exe
```

من شاشة تسجيل الدخول اضغط:

```text
إعداد الاتصال بالخادم
```

اكتب IP السيرفر والمنفذ:

```text
192.168.1.10:7070
```

النظام يحوله تلقائياً إلى:

```text
http://192.168.1.10:7070/api
```

اضغط:

```text
اختبار وحفظ
```

إذا نجح الاتصال، ارجع وسجل دخول.

## 5. تشغيل وإيقاف API على السيرفر

إيقاف مؤقت:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
```

تشغيل:

```powershell
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

إعادة تشغيل:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

حذف التشغيل التلقائي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\uninstall-api-autostart.ps1"
```

## 6. سجلات API

إذا حدثت مشكلة، افحص:

```powershell
Get-Content "D:\reservation_management_system\deploy\logs\reservation_api.out.log" -Tail 80
Get-Content "D:\reservation_management_system\deploy\logs\reservation_api.err.log" -Tail 80
```

## 7. ملاحظات أمان مهمة

داخل المؤسسة:

- استخدم IP داخلي مثل `192.168.x.x`.
- افتح فقط منفذ `7070` داخل الشبكة المحلية.

خارج المؤسسة:

- الأفضل استخدام VPN.
- أو استخدام Domain + HTTPS عبر Reverse Proxy.
- لا يفضل فتح منفذ `7070` مباشرة على الإنترنت.

## 8. تحديث نسخة موجودة عند الزبون

على جهاز المطور:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\build-customer-package.ps1" -ProjectRoot "D:\reservation_management_system"
```

ثم انسخ مجلد `deploy` المحدث إلى السيرفر.

على السيرفر:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name "reservation_api" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

إذا كان التحديث يحتوي تعديلات قاعدة بيانات، شغل:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE"
```
