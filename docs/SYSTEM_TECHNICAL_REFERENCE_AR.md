# المرجع التقني للنظام

هذا الملف مرجع عملي للتعديل اليدوي مستقبلاً. الهدف منه أن يوضح أين توجد كل صفحة، كيف تتحرك البيانات من الواجهة إلى الـ API ثم قاعدة البيانات، وما وظيفة أهم الدوال والبكجات المستخدمة.

## 1. الصورة العامة

النظام مكوّن من جزئين:

- تطبيق Flutter لواجهة المستخدم داخل مجلد `lib`.
- API مكتوب بـ Dart Shelf داخل مجلد `backend`.
- قاعدة بيانات PostgreSQL، والمخططات داخل `database/migrations`.
- ملفات تجهيز الزبون داخل `deploy`.

تدفق العملية غالباً يكون هكذا:

```text
Page Widget
  -> Riverpod Controller / Provider
  -> Frontend Repository
  -> ApiClient / Dio
  -> Backend Route
  -> Backend Controller
  -> Backend Repository
  -> PostgreSQL
```

مثال حقيقي: إضافة حجز

```text
ReservationsPage
  -> ReservationsController.create
  -> ReservationsRepository.createReservation
  -> POST /api/reservations
  -> ReservationsController.create في backend
  -> ReservationsRepository.create
  -> INSERT reservations + financial_transactions
```

## 2. تشغيل التطبيق والتهيئة

### Flutter

- نقطة الدخول: `lib/main.dart`
- التطبيق الرئيسي: `lib/core/app/app.dart`
- الراوتر: `lib/core/router/app_router.dart`
- الثيم: `lib/core/theme/app_theme.dart`
- الرابط الافتراضي للـ API: `lib/core/constants/app_constants.dart`

`main.dart` يشغّل `ProviderScope` حتى تعمل Riverpod في كامل التطبيق.

`ReservationManagementApp` يستخدم `MaterialApp.router` ويحدد اللغة العربية والثيم والراوتر.

`AppConstants.apiBaseUrl` يقرأ `API_BASE_URL` وقت البناء، وإلا يستخدم:

```text
http://localhost:7070/api
```

إذا أردت بناء نسخة تشير إلى API مختلف:

```powershell
flutter build windows --dart-define=API_BASE_URL=http://SERVER_IP:7070/api
```

### Backend

- نقطة الدخول: `backend/bin/server.dart`
- التهيئة الرئيسية: `backend/src/main.dart`
- إعدادات البيئة: `backend/src/config/app_config.dart`
- الاتصال بقاعدة البيانات: `backend/src/database/database_service.dart`
- الراوتر العام: `backend/src/routes/app_router.dart`

`startServer` يقوم بـ:

- قراءة `.env`.
- فتح اتصال PostgreSQL.
- إنشاء repositories/controllers.
- تشغيل `DatabaseSeeder` لإنشاء الأدوار وحساب المدير الافتراضي.
- تركيب middlewares.
- تشغيل السيرفر على `PORT`، غالباً `7070`.

## 3. نمط تنظيم الواجهة

كل Feature تقريباً مرتبة بهذا الشكل:

```text
lib/features/<feature>/
  data/<feature>_repository.dart
  models/<model>.dart
  presentation/controllers/<feature>_controller.dart
  presentation/pages/<feature>_page.dart
```

المسؤوليات:

- `page`: تبني الواجهة، الجداول، الفلاتر، الديالوكات.
- `controller`: يمسك حالة الشاشة، ينفذ البحث، الفلاتر، الصفحات، الإضافة، التعديل.
- `repository`: يتعامل مع API فقط.
- `model`: يحول JSON إلى كائن Dart.

## 4. ApiClient والتخزين

### `lib/core/network/api_client.dart`

هذا هو بوابة الاتصال بالـ API. يستخدم `Dio` ويضيف تلقائياً:

```text
Authorization: Bearer <token>
```

عبر `QueuedInterceptorsWrapper`.

إذا صار أي طلب API من Repository، لا تضيف التوكن يدوياً. فقط استخدم:

```dart
_apiClient.instance.get(...)
```

### `lib/core/storage/app_storage.dart`

يحفظ الجلسة والتوكن في `SharedPreferences`.

الدوال المهمة:

- `saveSession`: يحفظ التوكن ومعلومات المستخدم.
- `readSession`: يرجع الجلسة عند فتح التطبيق.
- `readAccessToken`: يستخدمها `ApiClient`.
- `clearSession`: تسجيل الخروج.

## 5. المصادقة والصلاحيات

### الواجهة

الملف: `lib/shared/models/auth_user.dart`

الدوال المهمة:

- `isSuperAdmin`: يفحص `SUPER_ADMIN` أو `SUPERADMIN`.
- `canModifyRecords`: يسمح بالإضافة والتعديل لأغلب الأدوار عدا `VIEWER`.
- `canDeleteRecords`: الحذف فقط للسوبر أدمن.
- `canManageUsers`: إدارة المستخدمين فقط للسوبر أدمن.
- `canExportReports`: يحدد إظهار أزرار تصدير التقارير.
- `canViewAuditLogs`: يمنع `VIEWER` و `DATA_ENTRY` من سجل الإجراءات.
- `canUseDataExchange`: يسمح بالاستيراد/التصدير فقط لـ `SUPER_ADMIN` و `ADMIN`.

### الراوتر

الملف: `lib/core/router/app_router.dart`

وظيفته:

- يمنع الدخول بدون تسجيل دخول.
- يحول المستخدم من `/login` إلى `/dashboard` إذا كان مسجل.
- يمنع الدخول المباشر إلى:
  - `/users` إذا ليس سوبر أدمن.
  - `/audit-logs` إذا لا يملك `canViewAuditLogs`.
  - `/data-exchange` إذا لا يملك `canUseDataExchange`.

### الباكند

الملف: `backend/src/middlewares/permission_middleware.dart`

الصلاحيات هناك تُفحص حسب `roleCode` الموجود داخل JWT.

الدوال المهمة:

- `protectedRoute`: يركب `authMiddleware` ثم `permissionMiddleware` إذا تم تمرير permission.
- `_hasPermission`: يحدد هل الدور يملك الصلاحية.

ملاحظات مهمة:

- الحذف وإدارة المستخدمين محصورة بالسوبر أدمن.
- سجل الإجراءات لا يظهر للـ `VIEWER` ولا `DATA_ENTRY`.
- بعض جداول قاعدة البيانات تحتوي `permissions` و `role_permissions`، لكن التطبيق حالياً يعتمد غالباً على `roleCode` داخل الكود وليس نظام صلاحيات ديناميكي بالكامل.

## 6. الصفحات والربط مع API

### 6.1 تسجيل الدخول

الملفات:

- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/controllers/auth_controller.dart`
- `lib/features/auth/data/auth_repository.dart`
- `backend/src/controllers/auth_controller.dart`
- `backend/src/repositories/auth_repository.dart`

Frontend:

- `AuthController.build`: يسترجع الجلسة من التخزين.
- `AuthController.login`: يستدعي repository.
- `AuthRepository.login`: يرسل `POST /auth/login`.
- `AuthRepository.me`: يقرأ المستخدم الحالي من `GET /auth/me`.

Backend:

- `POST /api/auth/login`: يفحص المستخدم وكلمة المرور ويصدر JWT.
- `GET /api/auth/me`: يرجع بيانات المستخدم من التوكن.

البكجات المهمة هنا:

- `shared_preferences` لحفظ الجلسة.
- `dio` للطلبات.
- `bcrypt` لتشفير كلمة المرور.
- `dart_jsonwebtoken` لإصدار وقراءة JWT.

### 6.2 لوحة التحكم

الملفات:

- `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
- `lib/features/dashboard/data/dashboard_repository.dart`
- `lib/shared/models/dashboard_summary.dart`
- `backend/src/controllers/dashboard_controller.dart`
- `backend/src/repositories/dashboard_repository.dart`

Frontend repository:

- `fetchSummary`: يطلب `/dashboard/summary`.
- `fetchBalanceAlerts`: يطلب `/dashboard/alerts`.
- `fetchSectionCards`: يطلب `/dashboard/section-cards`.

Providers:

- `dashboardSummaryProvider`: يحدث كل 10 ثواني.
- `balanceAlertsProvider`: يحدث كل 10 ثواني.
- `dashboardSectionCardsProvider(level)`: يجلب كاردات مستوى معين من الشجرة.

Backend:

- `fetchSummary`: يحسب إجمالي التخصيص، المحجوز، المصروف، المتبقي.
- `_fetchBalanceAlerts`: يرجع تنبيهات للأبواب التي اقتربت من حد الرصيد.
- `fetchSectionCards`: يجلب أبواب مستوى معين تحتوي أبناء، ويجمع تخصيص ومحجوز ومصروف الأبناء عبر SQL recursive.

نقطة مهمة في `fetchSectionCards`:

- المستخدم يحدد المستوى من الواجهة.
- الاستعلام يجلب فقط الأبواب بهذا المستوى التي لديها أبناء.
- يجمع مبالغ الأبناء النهائيين `is_postable`.
- عند الضغط على الكارد ينتقل إلى الحجوزات مع فلتر `program_id` و `budget_section_id`.

### 6.3 البرامج

الملفات:

- `lib/features/programs/presentation/pages/programs_page.dart`
- `lib/features/programs/presentation/controllers/programs_controller.dart`
- `lib/features/programs/data/programs_repository.dart`
- `backend/src/controllers/programs_controller.dart`
- `backend/src/repositories/programs_repository.dart`

Frontend controller:

- `build`: تحميل أول صفحة.
- `search`: بحث بالرمز أو الاسم.
- `filterFiscalYear`: فلترة حسب السنة.
- `create`: إضافة برنامج.
- `updateProgram`: تعديل.
- `remove`: حذف، ويظهر فقط لمن لديه صلاحية حذف.

API:

- `GET /api/programs`
- `POST /api/programs`
- `PUT /api/programs/<id>`
- `DELETE /api/programs/<id>`

ملاحظة: رمز البرنامج حالياً ليس محورياً مثل رمز الباب، وفي الاستيراد يمكن التعامل معه بمرونة حسب المنطق الحالي.

### 6.4 السنوات المالية

الملفات:

- `lib/features/fiscal_years/presentation/pages/fiscal_years_page.dart`
- `lib/features/fiscal_years/presentation/controllers/fiscal_years_controller.dart`
- `lib/features/fiscal_years/data/fiscal_years_repository.dart`
- `backend/src/controllers/fiscal_years_controller.dart`
- `backend/src/repositories/fiscal_years_repository.dart`

الدوال:

- `fetchFiscalYears`: قراءة السنوات.
- `createFiscalYear`: إضافة سنة.
- `updateFiscalYear`: تعديل.
- `activateFiscalYear`: جعل السنة مفتوحة.
- `deleteFiscalYear`: حذف، للسوبر أدمن فقط.

API:

- `GET /api/fiscal-years`
- `POST /api/fiscal-years`
- `PUT /api/fiscal-years/<id>`
- `PATCH /api/fiscal-years/<id>/activate`
- `DELETE /api/fiscal-years/<id>`

### 6.5 الأبواب المالية والشجرة

الملفات:

- `lib/features/budget_sections/presentation/pages/budget_sections_page.dart`
- `lib/features/budget_sections/presentation/controllers/budget_sections_controller.dart`
- `lib/features/budget_sections/data/budget_sections_repository.dart`
- `lib/features/budget_sections/models/budget_section_item.dart`
- `backend/src/controllers/budget_sections_controller.dart`
- `backend/src/repositories/budget_sections_repository.dart`

الحقول المهمة في جدول `budget_sections`:

- `parent_id`: الباب الأب.
- `level`: مستوى الباب.
- `full_code`: الكود الكامل.
- `is_postable`: هل الباب نهائي ويقبل تخصيص/حجز/صرف.
- `sort_order`: ترتيب داخل نفس المستوى.
- `path`: مسار الشجرة.
- `allocated_amount`: التخصيص السنوي المباشر.

قاعدة مهمة:

- الباب التجميعي لا يقبل حجز أو صرف مباشر.
- الباب النهائي فقط `is_postable = true` يقبل التخصيص والحجز والصرف.

Frontend:

- الشاشة تعرض Tree Grid.
- يمكن فتح وغلق الشجرة.
- يمكن إضافة باب رئيسي أو فرعي.
- يمكن تعديل التخصيص السنوي للباب.
- حذف الباب محصور بالسوبر أدمن.

API:

- `GET /api/budget-sections`
- `POST /api/budget-sections`
- `PUT /api/budget-sections/<id>`
- `DELETE /api/budget-sections/<id>`

ملاحظات تعديل يدوية:

- إذا أضفت حقل جديد للباب، عدّل:
  - Model في Flutter.
  - Repository payload.
  - Controller backend parsing.
  - Repository backend SQL.
  - ملف setup في `deploy/sql`.

### 6.6 الحجوزات

الملفات:

- `lib/features/reservations/presentation/pages/reservations_page.dart`
- `lib/features/reservations/presentation/controllers/reservations_controller.dart`
- `lib/features/reservations/data/reservations_repository.dart`
- `lib/features/reservations/models/reservation_item.dart`
- `backend/src/controllers/reservations_controller.dart`
- `backend/src/repositories/reservations_repository.dart`

الحالات المعتمدة حالياً عملياً:

- `محجوز`
- `معتمد`
- `مصروف`
- `ملغي`

الدوال المهمة في Flutter:

- `fetchReservations`: يجلب الحجوزات مع الفلاتر.
- `createReservation`: إضافة حجز.
- `submitForReview`: إرسال للمراجعة.
- `approve`: اعتماد.
- `cancel`: إلغاء.
- `deleteReservation`: حذف الحجز الملغي، للسوبر أدمن فقط.

الفلاتر:

- بحث.
- الحالة.
- البرنامج.
- الباب.
- من تاريخ.
- إلى تاريخ.

API:

- `GET /api/reservations`
- `POST /api/reservations`
- `PUT /api/reservations/<id>`
- `DELETE /api/reservations/<id>`
- `POST /api/reservations/<id>/submit-review`
- `POST /api/reservations/<id>/approve`
- `POST /api/reservations/<id>/cancel`
- توجد أيضاً نسخ `PATCH` للتوافق القديم.

الحساب المالي:

- عند اعتماد الحجز تسجل حركة `reservation_hold`.
- عند إلغاء الحجز تسجل حركة عكسية `reservation_cancel` أو `reservation_release`.
- إذا تم صرف أقل من مبلغ الحجز، يتم تحرير الفرق عبر migration `012_release_partial_spent_reservation_remainder.sql` والمنطق المرتبط به حتى لا يبقى باقي الحجز ممسكاً للتخصيص.

### 6.7 الصرف

الملفات:

- `lib/features/expenses/presentation/pages/expenses_page.dart`
- `lib/features/expenses/presentation/controllers/expenses_controller.dart`
- `lib/features/expenses/data/expenses_repository.dart`
- `lib/features/expenses/models/expense_item.dart`
- `backend/src/controllers/expenses_controller.dart`
- `backend/src/repositories/expenses_repository.dart`

الدوال:

- `fetchExpenses`: قراءة المصروفات مع الفلاتر.
- `createExpense`: إنشاء صرف من حجز معتمد.
- `cancelExpense`: إلغاء صرف.

الفلاتر:

- البحث.
- الحالة.
- البرنامج.
- الباب.
- الحجز.
- من تاريخ.
- إلى تاريخ.

API:

- `GET /api/expenses`
- `POST /api/expenses`
- `PATCH /api/expenses/<id>/cancel`

الحساب المالي:

- الصرف يسجل `expense_disbursement`.
- إلغاء الصرف يسجل `expense_cancel` أو reversal حسب المنطق.
- الصرف يكون من الحجز المعتمد.

### 6.8 التقارير

الملفات:

- `lib/features/reports/presentation/pages/reports_page.dart`
- `lib/features/reports/presentation/controllers/reports_controller.dart`
- `lib/features/reports/data/reports_repository.dart`
- `lib/features/reports/models/section_summary_item.dart`
- `lib/features/reports/services/report_export_service.dart`
- `backend/src/controllers/reports_controller.dart`
- `backend/src/repositories/reports_repository.dart`

Frontend:

- `sectionSummaryProvider`: يجلب تقرير ملخص الأبواب.
- `ReportsPage`: تعرض الفلاتر والجدول.
- `ReportExportService`: يصدر HTML و Excel.

الفلاتر:

- السنة المالية.
- البرنامج.
- الباب.
- الشهر.
- طريقة العرض حسب الباب أو البرنامج.
- ترتيب الجدول.
- إخفاء تخصيص 0.
- إظهار/إخفاء الأعمدة.

API:

- `GET /api/reports/section-summary`

التصدير:

- `exportSectionSummaryHtml`: ينشئ ملف HTML للطباعة.
- `exportSectionSummaryXlsx`: ينشئ Excel.

صلاحيات:

- `VIEWER` يرى التقارير داخل النظام، لكن لا تظهر له أزرار الطباعة أو HTML أو Excel.
- التصدير متاح حسب `canExportReports`.

### 6.9 التنبيهات

الملفات:

- `lib/features/alerts/presentation/pages/balance_alerts_page.dart`
- `lib/features/dashboard/data/dashboard_repository.dart`
- `backend/src/repositories/dashboard_repository.dart`

الصفحة تعتمد على:

- `GET /api/dashboard/alerts`

التنبيه يظهر عندما يكون المتبقي من الباب قريباً من حد معين، الافتراضي `50000`.

### 6.10 معلومات المؤسسة

الملفات:

- `lib/features/institution/presentation/pages/institution_page.dart`
- `lib/features/institution/presentation/controllers/institution_controller.dart`
- `lib/features/institution/data/institution_repository.dart`
- `backend/src/controllers/institution_controller.dart`
- `backend/src/repositories/institution_repository.dart`

API:

- `GET /api/institution`
- `PUT /api/institution`

تستخدم في:

- ترويسة التقارير.
- معلومات الطباعة.
- بيانات المؤسسة الرسمية.

### 6.11 المستخدمون

الملفات:

- `lib/features/users/presentation/pages/users_page.dart`
- `lib/features/users/presentation/controllers/users_controller.dart`
- `lib/features/users/data/users_repository.dart`
- `backend/src/controllers/users_controller.dart`
- `backend/src/repositories/users_repository.dart`

API:

- `GET /api/users`
- `GET /api/users/roles`
- `POST /api/users`
- `PUT /api/users/<id>`
- `PATCH /api/users/<id>/status`
- `PATCH /api/users/<id>/password`

صلاحية الوصول:

- فقط `SUPER_ADMIN`.

### 6.12 سجل الإجراءات

الملفات:

- `lib/features/audit_logs/presentation/pages/audit_logs_page.dart`
- `lib/features/audit_logs/presentation/controllers/audit_logs_controller.dart`
- `lib/features/audit_logs/data/audit_logs_repository.dart`
- `backend/src/controllers/audit_logs_controller.dart`
- `backend/src/repositories/audit_logs_repository.dart`
- `backend/src/services/audit_service.dart`

API:

- `GET /api/audit-logs`

الصلاحية:

- يظهر لـ `SUPER_ADMIN`, `ADMIN`, `FINANCE_MANAGER`, `REVIEWER`.
- لا يظهر لـ `VIEWER`.
- لا يظهر لـ `DATA_ENTRY`.

`AuditService.log` يستخدم في controllers لتسجيل الإنشاء والتعديل والحذف والاعتماد.

### 6.13 استيراد/تصدير

الملف الرئيسي:

- `lib/features/data_exchange/presentation/pages/data_exchange_page.dart`

الصفحة تعمل محلياً في Flutter وتستخدم:

- `excel` لإنشاء وقراءة ملفات Excel.
- `file_picker` لاختيار ملف من الجهاز.
- repositories الحالية لإرسال البيانات للـ API.

الصلاحية:

- فقط `SUPER_ADMIN` و `ADMIN`.

تدعم:

- قالب البرامج والأبواب.
- استيراد البرامج والأبواب.
- تصدير البرامج والأبواب.
- قالب الحجوزات.
- استيراد الحجوزات.
- تصدير الحجوزات.

ملاحظة مهمة:

- الاستيراد لا يكتب مباشرة في قاعدة البيانات، بل يمر عبر repositories والـ API حتى تبقى قواعد التحقق والسجل المالي وسجل الإجراءات شغالة.

## 7. API Routes المختصرة

كل المسارات تبدأ بـ `/api` في Flutter لأن `apiBaseUrl` ينتهي بـ `/api`.

| المجال | المسارات |
|---|---|
| Auth | `POST /auth/login`, `GET /auth/me` |
| Dashboard | `GET /dashboard/summary`, `GET /dashboard/alerts`, `GET /dashboard/section-cards` |
| Programs | `GET/POST /programs`, `PUT/DELETE /programs/<id>` |
| Budget Sections | `GET/POST /budget-sections`, `PUT/DELETE /budget-sections/<id>` |
| Fiscal Years | `GET/POST /fiscal-years`, `PUT/DELETE /fiscal-years/<id>`, `PATCH /fiscal-years/<id>/activate` |
| Budget Types | `GET/POST /budget-types`, `PUT/DELETE /budget-types/<id>` |
| Reservations | `GET/POST /reservations`, `PUT/DELETE /reservations/<id>`, `POST /reservations/<id>/approve` |
| Expenses | `GET/POST /expenses`, `PATCH /expenses/<id>/cancel` |
| Reports | `GET /reports/section-summary` |
| Institution | `GET/PUT /institution` |
| Users | `GET/POST /users`, `GET /users/roles`, `PUT /users/<id>`, `PATCH /users/<id>/status`, `PATCH /users/<id>/password` |
| Audit Logs | `GET /audit-logs` |

## 8. البنية الخلفية Backend

كل Feature في backend غالباً يتكون من:

```text
routes/<feature>_routes.dart
controllers/<feature>_controller.dart
repositories/<feature>_repository.dart
models/<model>.dart
```

المسؤوليات:

- `routes`: تعريف URL وربط الصلاحية.
- `controller`: قراءة query/body، التحقق الأولي، فتح transaction.
- `repository`: SQL الفعلي.
- `model`: تحويل الصفوف إلى JSON.

قاعدة مهمة:

- أي عملية تعدّل بيانات مهمة يجب أن تكون داخل `database.runTx`.
- أي عملية مالية يجب أن تحدث جدول العمل وجدول `financial_transactions` معاً.
- أي عملية مهمة يجب أن تسجل في `audit_logs` عبر `AuditService`.

## 9. قاعدة البيانات والمigrations

المسار:

```text
database/migrations
```

أهم الملفات:

- `001_initial_schema.sql`: الجداول الأساسية.
- `002_financial_foundation_upgrade.sql`: السنوات المالية، أنواع الميزانية، الصلاحيات، التمويل الشهري القديم.
- `006_institution_settings.sql`: معلومات المؤسسة وسجل الإجراءات.
- `009_suspend_monthly_fundings_restore_annual_allocation.sql`: تعليق التمويل الشهري والعودة للتخصيص السنوي.
- `010_add_reservation_tracking_fields.sql`: حقول إضافية للحجوزات مثل الجهة والقسم والهاتف.
- `010_super_admin_permissions.sql`: صلاحيات السوبر أدمن.
- `011_budget_sections_hierarchy.sql`: دعم الشجرة الهرمية للأبواب.
- `012_release_partial_spent_reservation_remainder.sql`: تحرير باقي الحجز عند صرف أقل من مبلغ الحجز.

ملف تسليم الزبون:

```text
deploy/sql/001_customer_database_setup.sql
```

أي تعديل SQL مهم لازم ينعكس أيضاً في ملف `deploy/sql/001_customer_database_setup.sql` إذا تريد نسخة زبون نظيفة.

## 10. البكجات المستخدمة في Flutter

### `flutter_riverpod`

إدارة الحالة وربط الصفحات بالبيانات.

استخدمناه في:

- `AsyncNotifierProvider` للشاشات التي لديها حالة وفلاتر وصفحات.
- `FutureProvider` للـ lookups مثل السنوات والبرامج.
- `StreamProvider` للتحديث التلقائي.

نمط الاستخدام:

```dart
final state = ref.watch(programsControllerProvider);
ref.read(programsControllerProvider.notifier).search(value);
```

### `go_router`

إدارة التنقل والحماية.

استخدمناه في:

- تعريف مسارات الصفحات.
- `ShellRoute` لعرض `AppShell`.
- redirect حسب الجلسة والصلاحيات.

### `dio`

HTTP Client.

استخدمناه في:

- جميع repositories داخل Flutter.
- interceptor لإضافة JWT تلقائياً.
- تحويل أخطاء API إلى `AppException`.

### `shared_preferences`

حفظ التوكن والجلسة محلياً.

### `intl`

تنسيق:

- العملات `NumberFormat.currency`.
- التواريخ `DateFormat`.
- أسماء الأشهر.

### `flutter_form_builder`

بناء النماذج داخل الديالوكات بشكل أسرع ومنظم.

### `form_builder_validators`

التحقق من الحقول مثل required والرقم والتاريخ.

### `fl_chart`

رسم مخططات الداشبورد.

### `syncfusion_flutter_datagrid`

الجداول المتقدمة، خاصة:

- التقارير.
- الجداول التي تحتاج scroll أفقي.
- أعمدة متعددة وقيم مالية.

### `excel`

إنشاء وقراءة ملفات Excel في صفحة الاستيراد/التصدير والتقارير.

### `file_picker`

اختيار ملف Excel من جهاز المستخدم.

### `google_fonts`

دعم الخطوط. المشروع يعتمد واجهة عربية وخط Cairo غالباً من الثيم.

## 11. البكجات المستخدمة في Backend

### `shelf`

أساس HTTP Server.

استخدمناه في:

- Request/Response.
- Middlewares.
- تشغيل السيرفر.

### `shelf_router`

تعريف المسارات مثل:

```dart
router.get('/api/programs', ...)
```

### `shelf_cors_headers`

إضافة CORS headers حتى يسمح للواجهة بالاتصال بالـ API.

### `postgres`

الاتصال بقاعدة PostgreSQL وتنفيذ SQL.

نستخدم:

- `Connection.openFromUrl`.
- `session.execute`.
- `Sql.named`.
- `runTx`.

### `dotenv`

قراءة `.env` في backend.

### `logging`

طباعة log منظم للسيرفر والطلبات.

### `bcrypt`

تشفير كلمات المرور والتحقق منها.

### `dart_jsonwebtoken`

إنشاء وقراءة JWT.

### `uuid`

مفيد لتوليد UUID إذا احتجناه داخل الكود، مع أن PostgreSQL أيضاً يستخدم `gen_random_uuid`.

## 12. التحديث التلقائي للبيانات

في الواجهة يوجد:

- `lib/core/providers/live_refresh_provider.dart`: نبض كل 3 ثواني.
- بعض Providers مثل الداشبورد تعمل invalidate كل 10 ثواني.

الفكرة:

- لا يوجد WebSocket حالياً.
- التحديث شبه مباشر عن طريق polling.
- عند الإضافة أو التعديل، controllers تعمل `refresh` أو `invalidate` للـ providers المرتبطة.

إذا أردت تحديثاً لحظياً حقيقياً مستقبلاً:

- أضف WebSocket أو Server-Sent Events.
- استبدل polling في `liveRefreshProvider`.

## 13. أهم قواعد العمل المالي

- التخصيص المعتمد حالياً هو التخصيص السنوي للباب `budget_sections.allocated_amount`.
- التمويل الشهري معلّق مؤقتاً.
- الحجز يعتمد على الباب النهائي.
- الصرف يتم من حجز معتمد.
- الحجز الملغي لا يدخل في المجاميع المالية، لكنه يبقى أرشيفاً.
- عند صرف أقل من الحجز، الفرق المتبقي يتحرر من المحجوز ولا يضاف كتخصيص جديد.
- التقارير والداشبورد تعتمد على `financial_transactions` مع بيانات الأبواب.

## 14. أين أعدل إذا أردت إضافة حقل جديد؟

مثال: إضافة حقل جديد للحجز.

1. Database:
   - أضف migration جديد في `database/migrations`.
   - حدّث `deploy/sql/001_customer_database_setup.sql`.

2. Backend model:
   - `backend/src/models/reservation.dart`

3. Backend repository:
   - `backend/src/repositories/reservations_repository.dart`
   - أضف الحقل في SELECT/INSERT/UPDATE.

4. Backend controller:
   - `backend/src/controllers/reservations_controller.dart`
   - اقرأ الحقل من body وتحقق منه.

5. Frontend model:
   - `lib/features/reservations/models/reservation_item.dart`

6. Frontend repository:
   - `lib/features/reservations/data/reservations_repository.dart`

7. Frontend page:
   - `lib/features/reservations/presentation/pages/reservations_page.dart`

8. Excel import/export إذا يخص الحجز:
   - `lib/features/data_exchange/presentation/pages/data_exchange_page.dart`

9. Reports إذا يظهر بالتقارير:
   - `lib/features/reports/...`

## 15. أوامر مفيدة للتطوير

تحليل Flutter:

```powershell
flutter analyze
```

تحليل Backend:

```powershell
cd D:\reservation_management_system\backend
dart analyze
```

تشغيل Backend:

```powershell
cd D:\reservation_management_system\backend
dart run bin\server.dart
```

بناء API exe:

```powershell
cd D:\reservation_management_system\backend
dart compile exe bin\server.dart -o ..\deploy\api\reservation_api.exe
```

تشغيل watchdog:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\reservation_management_system\deploy\scripts\reservation-api-watchdog.ps1" -InstallRoot "D:\reservation_management_system\deploy"
```

فحص API:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:7070/health -UseBasicParsing
```

تشغيل seed تجريبي:

```powershell
$env:PGPASSWORD='ali'
psql -h localhost -U postgres -d reservation_management -f "D:\reservation_management_system\database\seeds\003_demo_financial_tree_data.sql"
```

## 16. نقاط انتباه قبل أي تعديل

- لا تعدل API route بدون تعديل frontend repository المقابل.
- لا تضف عمود SQL بدون تعديل model في الطرفين.
- لا تجعل عمليات مالية خارج transaction.
- لا تكتب مباشرة في الجداول من الاستيراد؛ مرّرها عبر API حتى يبقى التحقق والسجل المالي شغال.
- إذا غيّرت صلاحية، عدّل:
  - `lib/shared/models/auth_user.dart`
  - `backend/src/middlewares/permission_middleware.dart`
  - `lib/core/router/app_router.dart` إذا الصفحة تحتاج منع دخول مباشر.
  - `lib/widgets/app_sidebar.dart` إذا تريد إخفاء/إظهار عنصر بالقائمة.
- إذا غيّرت قاعدة بيانات للزبون، حدّث `deploy/sql/001_customer_database_setup.sql`.

