# Phase 1 Foundation

هذا المستند يشرح ما تم بناؤه في المرحلة الأولى: `Project Setup`, `Authentication`, `Layout`, `Database Connection`.

## سبب التقسيم

- `lib/core`: البنية المشتركة مثل الثيم، الراوتر، التخزين، وعميل الـ API.
- `lib/shared`: النماذج المشتركة بين المزايا والـ widgets العامة.
- `lib/features/auth`: منطق تسجيل الدخول واستعادة الجلسة.
- `lib/features/dashboard`: أول Dashboard مرتبط فعلياً بالـ API.
- `lib/layouts`: غلاف التطبيق الرئيسي `Sidebar + Topbar`.
- `backend/src/config`: إعدادات البيئة وتهيئة السجلات.
- `backend/src/database`: الاتصال بقاعدة البيانات والـ seeding.
- `backend/src/repositories`: الوصول إلى PostgreSQL بعزل واضح عن الـ controllers.
- `backend/src/services`: JWT, bcrypt, responses, body parsing, audit logging.
- `backend/src/controllers`: منطق نقاط النهاية.
- `backend/src/middlewares`: المصادقة، معالجة الأخطاء، وحماية الرؤوس.
- `backend/src/routes`: تسجيل المسارات بعيداً عن منطق التنفيذ.

## الملفات المهمة ولماذا أُنشئت

- [lib/core/router/app_router.dart](/d:/reservation_management_system/lib/core/router/app_router.dart): يفرض التنقل بحسب حالة الجلسة ويمنع الوصول غير المصرح به.
- [lib/features/auth/presentation/controllers/auth_controller.dart](/d:/reservation_management_system/lib/features/auth/presentation/controllers/auth_controller.dart): مصدر الحقيقة لحالة الدخول باستخدام Riverpod.
- [lib/features/auth/data/auth_repository.dart](/d:/reservation_management_system/lib/features/auth/data/auth_repository.dart): يعزل التخزين المحلي واستدعاءات الـ API عن الواجهة.
- [lib/layouts/app_shell.dart](/d:/reservation_management_system/lib/layouts/app_shell.dart): يثبت التصميم الحكومي الأساسي لسطح المكتب.
- [lib/features/dashboard/presentation/pages/dashboard_page.dart](/d:/reservation_management_system/lib/features/dashboard/presentation/pages/dashboard_page.dart): يعرض المؤشرات المالية الأولية باستخدام `fl_chart` و`Syncfusion DataGrid`.
- [backend/src/database/database_service.dart](/d:/reservation_management_system/backend/src/database/database_service.dart): نقطة الاتصال المركزية مع PostgreSQL.
- [backend/src/database/database_seeder.dart](/d:/reservation_management_system/backend/src/database/database_seeder.dart): يضمن وجود الأدوار وحساب المدير الافتراضي.
- [backend/src/controllers/auth_controller.dart](/d:/reservation_management_system/backend/src/controllers/auth_controller.dart): تسجيل الدخول وقراءة المستخدم الحالي.
- [backend/src/services/audit_service.dart](/d:/reservation_management_system/backend/src/services/audit_service.dart): يسجل الأحداث الحساسة في `audit_logs`.
- [database/migrations/001_initial_schema.sql](/d:/reservation_management_system/database/migrations/001_initial_schema.sql): المخطط الكامل للجداول والعلاقات والـ view المالي.

## العلاقات الحالية

- `users.role_id -> roles.id`
- `budget_sections.program_id -> programs.id`
- `fundings.program_id -> programs.id`
- `fundings.budget_section_id -> budget_sections.id`
- `reservations.program_id -> programs.id`
- `reservations.budget_section_id -> budget_sections.id`
- `reservations.funding_id -> fundings.id`
- `expenses.reservation_id -> reservations.id`
- `financial_transactions` يرتبط اختيارياً بـ `programs`, `budget_sections`, `fundings`, `reservations`, `expenses`
- `audit_logs.created_by -> users.id`

## كيف يعمل النظام حالياً

1. يتم تحميل إعدادات الـ backend من `.env`.
2. يتصل الخادم بقاعدة البيانات ثم ينفذ `seedFoundation`.
3. عند تسجيل الدخول:
   يتم جلب المستخدم، التحقق من كلمة المرور بـ `bcrypt`, إصدار JWT، وتسجيل الحدث في `audit_logs`.
4. يحتفظ الـ frontend بالجلسة محلياً عبر `SharedPreferences`.
5. الراوتر يوجه المستخدم إلى `Dashboard` فقط عند وجود جلسة صحيحة.
6. الـ Dashboard يقرأ القيم من view `dashboard_financial_summary`.

## نقاط مالية مقصودة في التصميم

- لا يوجد حقل مباشر لـ `remaining_balance` داخل الجداول التشغيلية.
- الرصيد المتبقي يُحسب من `financial_transactions`.
- أي عملية مالية مستقبلية يجب أن تمر عبر PostgreSQL transaction وتولّد قيود Ledger بدلاً من تعديل الأرقام مباشرة.

## تحسينات مقترحة للمرحلة التالية

- إضافة `Programs` و`Budget Sections` مع CRUD وPagination وSearch.
- إنشاء service خاص بالـ workflow للحجوزات.
- إضافة RBAC أدق على مستوى الأفعال وليس الدور فقط.
- إضافة refresh tokens أو إدارة جلسات أكثر صرامة.
- إضافة migration runner آلي مثل `dbmate` أو سكربت Dart داخلي.
