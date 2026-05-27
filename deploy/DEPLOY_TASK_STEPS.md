# خطوات Deploy وتنصيب الزبون

## A. بناء نسخة التسليم عند المطور

1. افتح PowerShell كمسؤول أو عادي على جهاز المطور.

2. أوقف API المحلي حتى لا يقفل ملف `reservation_api.exe`:

```powershell
$currentProcessId = $PID
Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $currentProcessId -and $_.CommandLine -like '*reservation-api-watchdog.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process -Name reservation_api -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name reservation_management_system -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
```

3. ابن نسخة التسليم:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\build-customer-package.ps1" -ProjectRoot "D:\reservation_management_system"
```

4. الملفات الجاهزة للتسليم تكون هنا:

```text
D:\reservation_management_system\deploy
```

5. انسخ مجلد `deploy` كاملاً إلى جهاز الزبون داخل:

```text
D:\reservation_management_system\deploy
```

## B. تنصيب السيرفر عند الزبون

نفذ الأوامر التالية على جهاز السيرفر فقط، من PowerShell بصلاحية Administrator.

1. ثبّت PostgreSQL وخذ كلمة مرور مستخدم `postgres`.

2. جهز قاعدة البيانات:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE"
```

إذا `psql` غير معروف:
PostgreSQL\16\bin بال  باث او اخلي مسار 
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-database.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -PsqlPath "C:\Program Files\PostgreSQL\16\bin\psql.exe"
```

3. أنشئ ملف إعدادات API:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\create-api-env.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DatabasePassword "PASSWORD_HERE" -AdminUsername "admin" -AdminPassword "Admin@12345"
```

4. شغل API تلقائياً مع Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-api-autostart.ps1" -InstallRoot "D:\reservation_management_system\deploy"
```

5. افتح منفذ API بالشبكة:

```powershell
New-NetFirewallRule -DisplayName "Reservation Management API 7070" -Direction Inbound -Protocol TCP -LocalPort 7070 -Action Allow
```

6. اختبر API على السيرفر:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:7070/health" -UseBasicParsing
```

7. اعرف IP السيرفر:

```powershell
ipconfig
```

## C. تفعيل النسخ الاحتياطي التلقائي

1. إذا `pg_dump` غير معروف، افتح:

```text
D:\reservation_management_system\deploy\api\.env
```

وأضف أو عدل:

```text
PG_DUMP_PATH=C:\Program Files\PostgreSQL\16\bin\pg_dump.exe
PG_RESTORE_PATH=C:\Program Files\PostgreSQL\16\bin\pg_restore.exe
BACKUP_DIR=backups
BACKUP_RETENTION_DAYS=30
```

2. فعّل Backup تلقائي يومياً الساعة 02:00:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\install-backup-task.ps1" -InstallRoot "D:\reservation_management_system\deploy" -DailyAt "02:00"
```

3. جرّب Backup يدوي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\run-database-backup.ps1" -ApiRoot "D:\reservation_management_system\deploy\api"
```

4. مكان النسخ:

```text
D:\reservation_management_system\deploy\api\backups
```

## D. تجهيز الأجهزة الفرعية

1. انسخ مجلد التطبيق فقط لكل جهاز:

```text
D:\reservation_management_system\deploy\app
```

2. شغل:

```text
D:\reservation_management_system\deploy\app\reservation_management_system.exe
```

3. من شاشة تسجيل الدخول افتح `إعداد الاتصال بالخادم`.

4. اكتب IP السيرفر:

```text
192.168.1.10:7070
```

أو:

```text
http://192.168.1.10:7070/api
```

5. اضغط `اختبار وحفظ` ثم سجل دخول.

## E. أوامر إدارة الخدمة

إيقاف API:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name reservation_api -ErrorAction SilentlyContinue | Stop-Process -Force
```

تشغيل API:

```powershell
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

إعادة تشغيل API:

```powershell
Stop-ScheduledTask -TaskName "ReservationManagementAPI"
Get-Process -Name reservation_api -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "ReservationManagementAPI"
```

حذف تشغيل API التلقائي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\uninstall-api-autostart.ps1"
```

حذف Backup التلقائي:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\reservation_management_system\deploy\scripts\uninstall-backup-task.ps1"
```
