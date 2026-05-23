# ملخص متغيرات Riverpod في النظام

هذا الملف يلخص كل متغيرات Riverpod المستخدمة في واجهة Flutter، والغرض من كل واحد منها. الفكرة أن يكون عندك مرجع سريع قبل أي تعديل يدوي.

## القاعدة العامة

اعتمدنا نمط ثابت تقريباً في كل Feature:

| النوع | وظيفته |
|---|---|
| `RepositoryProvider` | ينشئ Repository ويربطه مع `apiClientProvider` حتى يتصل بالـ API. |
| `LookupProvider` | يجلب قائمة خفيفة للاستخدام داخل القوائم المنسدلة أو الاستيراد والتصدير. |
| `ControllerProvider` | يدير حالة الصفحة: تحميل، بحث، فلاتر، صفحات، إضافة، تعديل، حذف. |
| `FutureProvider.family` | يجلب بيانات تعتمد على مدخلات مثل فلتر أو سنة مالية أو مستوى شجرة. |
| `StreamProvider` | يعطي نبض تحديث تلقائي للشاشات بدون WebSocket. |

## Providers الأساسية

| Provider | الملف | النوع | الغرض |
|---|---|---|---|
| `appStorageProvider` | `lib/features/auth/presentation/providers/auth_providers.dart` | `Provider<AppStorage>` | يوفر التخزين المحلي للتوكن وبيانات الجلسة. |
| `apiClientProvider` | `lib/features/auth/presentation/providers/auth_providers.dart` | `Provider<ApiClient>` | ينشئ عميل الاتصال بالـ API ويقرأ التوكن من `AppStorage`. هذا هو العمود الفقري لكل Repository. |
| `authRepositoryProvider` | `lib/features/auth/presentation/providers/auth_providers.dart` | `Provider<AuthRepository>` | يربط تسجيل الدخول والخروج واسترجاع الجلسة مع الـ API والتخزين المحلي. |
| `authControllerProvider` | `lib/features/auth/presentation/controllers/auth_controller.dart` | `AsyncNotifierProvider<AuthController, AuthSession?>` | يدير حالة تسجيل الدخول الحالية: يرجع الجلسة عند التشغيل، ينفذ login/logout، وتراقبه الصفحات والصلاحيات. |
| `appRouterProvider` | `lib/core/router/app_router.dart` | `Provider<GoRouter>` | يبني Routes ويعتمد على `authControllerProvider` لمعرفة هل المستخدم مسجل دخول ولتطبيق التحويلات حسب الصلاحيات. |
| `liveRefreshProvider` | `lib/core/providers/live_refresh_provider.dart` | `StreamProvider.autoDispose<int>` | نبض كل 3 ثواني تستخدمه صفحات مثل الحجوزات والصرف والتقارير وسجل الإجراءات لإعادة القراءة تلقائياً. |

## لوحة التحكم والتنبيهات

| Provider | النوع | الغرض |
|---|---|---|
| `dashboardRepositoryProvider` | `Provider<DashboardRepository>` | يربط مستودع الداشبورد مع `apiClientProvider`. |
| `dashboardSummaryProvider` | `FutureProvider.autoDispose<DashboardSummary>` | يجلب أرقام الداشبورد العامة: التخصيص، المحجوز، المصروف، المتبقي. يعيد تحديث نفسه كل 10 ثواني. |
| `dashboardSummaryByFiscalYearProvider` | `FutureProvider.autoDispose.family<DashboardSummary, String?>` | يجلب ملخص الداشبورد حسب سنة مالية محددة. |
| `balanceAlertsProvider` | `FutureProvider.autoDispose<List<DashboardBalanceAlert>>` | يجلب تنبيهات الرصيد المنخفض أو قرب نفاد التخصيص، ويحدث نفسه كل 10 ثواني. |
| `dashboardSectionCardsProvider` | `FutureProvider.autoDispose.family<List<DashboardSectionCard>, int>` | يجلب كاردات الأبواب حسب المستوى المختار من المستخدم، ويحسب تخصيص الأبناء والمحجوز والعدد. |

## البرامج

| Provider | النوع | الغرض |
|---|---|---|
| `programsRepositoryProvider` | `Provider<ProgramsRepository>` | اتصال API الخاص بالبرامج. |
| `programLookupProvider` | `FutureProvider<List<ProgramItem>>` | قائمة البرامج المختصرة للقوائم المنسدلة والاستيراد والتصدير. |
| `programsControllerProvider` | `AsyncNotifierProvider<ProgramsController, ProgramsState>` | حالة صفحة البرامج: البحث، الفلترة بالسنة، التصفح، إضافة، تعديل، حذف. |

## السنوات المالية

| Provider | النوع | الغرض |
|---|---|---|
| `fiscalYearsRepositoryProvider` | `Provider<FiscalYearsRepository>` | اتصال API الخاص بالسنوات المالية. |
| `fiscalYearsLookupProvider` | `FutureProvider<List<FiscalYearItem>>` | قائمة السنوات المالية للاستخدام في الفلاتر والقوالب والاستيراد. |
| `fiscalYearsControllerProvider` | `AsyncNotifierProvider<FiscalYearsController, FiscalYearsState>` | حالة صفحة السنوات المالية: بحث، صفحات، إنشاء، تعديل، تفعيل، حذف. |

## أنواع الميزانية

> حالياً دمجنا مفهوم نوع الميزانية مع البرامج عملياً، لكن الكود لا يزال موجوداً للتوافق وعدم كسر النظام.

| Provider | النوع | الغرض |
|---|---|---|
| `budgetTypesRepositoryProvider` | `Provider<BudgetTypesRepository>` | اتصال API الخاص بأنواع الميزانية. |
| `budgetTypesLookupProvider` | `FutureProvider<List<BudgetTypeItem>>` | قائمة أنواع الميزانية القديمة للقوائم أو الأكواد التي ما زالت تعتمد عليها. |
| `budgetTypesControllerProvider` | `AsyncNotifierProvider<BudgetTypesController, BudgetTypesState>` | حالة صفحة أنواع الميزانية القديمة إن فُعّلت مستقبلاً. |

## الأبواب المالية

| Provider | النوع | الغرض |
|---|---|---|
| `budgetSectionsRepositoryProvider` | `Provider<BudgetSectionsRepository>` | اتصال API الخاص بالأبواب المالية والشجرة الهرمية. |
| `allBudgetSectionsLookupProvider` | `FutureProvider<List<BudgetSectionItem>>` | يجلب حتى 1000 باب لاستخدامها في القوائم المنسدلة، الحجز، الصرف، التقارير، والاستيراد والتصدير. |
| `budgetSectionsControllerProvider` | `AsyncNotifierProvider<BudgetSectionsController, BudgetSectionsState>` | حالة صفحة الأبواب: البحث، البرنامج، السنة، النوع، عرض الشجرة، إضافة باب رئيسي/فرعي، تعديل، حذف. |

ملاحظات مهمة:

- بعد إنشاء أو تعديل أو حذف باب يتم عمل `ref.invalidate(allBudgetSectionsLookupProvider)` حتى تتحدث القوائم المنسدلة.
- `budgetSectionsControllerProvider` يستخدم PageSize كبير حتى لا تنقطع فروع الشجرة بين الصفحات.

## التخصيصات / Fundings القديمة

| Provider | النوع | الغرض |
|---|---|---|
| `fundingsRepositoryProvider` | `Provider<FundingsRepository>` | اتصال API للتخصيصات القديمة. |
| `fundingsLookupProvider` | `FutureProvider<List<FundingItem>>` | قائمة تخصيصات مختصرة كانت تستخدم سابقاً مع الحجوزات. |
| `fundingsControllerProvider` | `AsyncNotifierProvider<FundingsController, FundingsState>` | حالة صفحة التخصيصات القديمة. |

ملاحظة:

- بعد التحول إلى التخصيص السنوي على الباب، الاعتماد الأساسي صار على `allocatedAmount` داخل `budget_sections`، لكن هذه الـ Providers باقية حتى لا ينكسر كود قديم.

## التمويل الشهري

| Provider | النوع | الغرض |
|---|---|---|
| `monthlyFundingsRepositoryProvider` | `Provider<MonthlyFundingsRepository>` | اتصال API الخاص بالتمويل الشهري. |
| `monthlyFundingsControllerProvider` | `AsyncNotifierProvider<MonthlyFundingsController, MonthlyFundingsState>` | حالة صفحة التمويل الشهري: بحث، سنة، برنامج، شهر، إضافة، تعديل، حذف. |

ملاحظة:

- شاشة التمويل الشهري معلقة حالياً في الراوتر، لأن المفهوم رجع للتخصيص السنوي للأبواب لحين تثبيت القرار المحاسبي.

## الحجوزات

| Provider | النوع | الغرض |
|---|---|---|
| `reservationsRepositoryProvider` | `Provider<ReservationsRepository>` | اتصال API الخاص بالحجوزات. |
| `reservationsControllerProvider` | `AsyncNotifierProvider<ReservationsController, ReservationsState>` | حالة صفحة الحجوزات: بحث، حالة الحجز، البرنامج، الباب، التنفيذ، الفترة، إضافة، اعتماد، إلغاء، حذف. |

ملاحظات مهمة:

- عند تغيير الحجز يتم تحديث الداشبورد والتقارير عبر `ref.invalidate(...)`.
- صفحة الحجوزات تسمع `liveRefreshProvider` حتى تتحدث تلقائياً.
- الحجز يعتمد على الباب النهائي `isPostable = true` وليس الباب التجميعي.

## الصرف

| Provider | النوع | الغرض |
|---|---|---|
| `expensesRepositoryProvider` | `Provider<ExpensesRepository>` | اتصال API الخاص بالمصروفات. |
| `spendableReservationsProvider` | `FutureProvider<List<ReservationItem>>` | يجلب الحجوزات القابلة للصرف، ويصفيها إلى الحجوزات المعتمدة فقط. |
| `expensesControllerProvider` | `AsyncNotifierProvider<ExpensesController, ExpensesState>` | حالة صفحة الصرف: بحث، حجز، برنامج، باب، فترة، إضافة صرف، إلغاء صرف، حذف/تحديث. |

ملاحظات مهمة:

- بعد إضافة أو إلغاء صرف يتم تحديث: الحجوزات، الداشبورد، التقارير، والحجوزات القابلة للصرف.
- `spendableReservationsProvider` مهم حتى لا تظهر حجوزات غير معتمدة داخل Dialog الصرف.

## التقارير

| Provider | النوع | الغرض |
|---|---|---|
| `reportsRepositoryProvider` | `Provider<ReportsRepository>` | اتصال API الخاص بالتقارير. |
| `sectionSummaryProvider` | `FutureProvider.autoDispose.family<List<SectionSummaryItem>, SectionSummaryFilters>` | يجلب تقرير ملخص الباب حسب الفلاتر: سنة، برنامج، باب، فترة. |

ملاحظات مهمة:

- لأن `sectionSummaryProvider` هو `family`، أي تغيير بالفلتر ينتج قراءة جديدة.
- `SectionSummaryFilters` يحتوي `==` و`hashCode` حتى Riverpod يعرف متى الفلتر تغيّر فعلاً.
- صفحة التقارير تسمع `liveRefreshProvider` وتعمل `invalidate` للتقرير الحالي.

## المؤسسة

| Provider | النوع | الغرض |
|---|---|---|
| `institutionRepositoryProvider` | `Provider<InstitutionRepository>` | اتصال API الخاص بمعلومات المؤسسة. |
| `institutionControllerProvider` | `AsyncNotifierProvider<InstitutionController, InstitutionSettingsItem>` | يجلب ويحفظ إعدادات المؤسسة المستخدمة في الترويسات والتقارير والطباعة. |

## المستخدمون والصلاحيات

| Provider | النوع | الغرض |
|---|---|---|
| `usersRepositoryProvider` | `Provider<UsersRepository>` | اتصال API الخاص بالمستخدمين والأدوار. |
| `userRolesProvider` | `FutureProvider<List<UserRoleItem>>` | يجلب الأدوار لاستخدامها في شاشة إنشاء/تعديل المستخدم. |
| `usersControllerProvider` | `AsyncNotifierProvider<UsersController, UsersState>` | حالة صفحة المستخدمين: بحث، فلترة بالدور والحالة، إضافة، تعديل، تفعيل/تعطيل. |

ملاحظات مهمة:

- `userRolesProvider` يتم تحديثه عند الحاجة باستخدام `ref.invalidate(userRolesProvider)`.
- الصلاحيات الفعلية تحفظ داخل الجلسة في `authControllerProvider` وتستخدمها الواجهة لإظهار/إخفاء الأزرار والصفحات.

## سجل الإجراءات

| Provider | النوع | الغرض |
|---|---|---|
| `auditLogsRepositoryProvider` | `Provider<AuditLogsRepository>` | اتصال API الخاص بسجل الإجراءات. |
| `auditLogsControllerProvider` | `AsyncNotifierProvider<AuditLogsController, AuditLogsState>` | حالة صفحة سجل الإجراءات: بحث، صفحات، تحديث. |

ملاحظة:

- صفحة سجل الإجراءات لا تظهر إلا لمن يملك صلاحية `viewAuditLogs`.
- الصفحة تستخدم `liveRefreshProvider` حتى تظهر الإجراءات الجديدة بدون إعادة فتح الصفحة.

## جدول مختصر سريع

| إذا تريد... | استخدم |
|---|---|
| الاتصال بالـ API | `apiClientProvider` داخل RepositoryProvider |
| معرفة المستخدم الحالي | `ref.watch(authControllerProvider).asData?.value` |
| عرض صفحة كاملة فيها بحث وفلاتر | `AsyncNotifierProvider` |
| قائمة Dropdown | `FutureProvider` باسم `LookupProvider` |
| تحديث بيانات بعد عملية | `ref.invalidate(providerName)` |
| تنفيذ عملية من زر | `ref.read(controllerProvider.notifier).method()` |
| قراءة بيانات داخل build | `ref.watch(providerName)` |
| قراءة مرة واحدة داخل دالة | `ref.read(providerName)` |
| تحديث تلقائي دوري | `liveRefreshProvider` أو Timer داخل `FutureProvider.autoDispose` |

## أهم علاقات الاعتماد

```text
ProviderScope
  -> appStorageProvider
  -> apiClientProvider
  -> RepositoryProvider
  -> ControllerProvider / LookupProvider
  -> Page Widgets
```

مثال عملي:

```text
BudgetSectionsPage
  watches budgetSectionsControllerProvider
  watches programLookupProvider
  watches fiscalYearsLookupProvider
  watches allBudgetSectionsLookupProvider

BudgetSectionsController
  reads budgetSectionsRepositoryProvider

BudgetSectionsRepository
  uses apiClientProvider

ApiClient
  uses appStorageProvider
```

## ملاحظات تنظيمية

- لا تستدعي Repository مباشرة داخل الصفحة إذا عندك Controller لنفس الشاشة.
- استخدم `LookupProvider` فقط للقوائم المختصرة، وليس لإدارة صفحة كاملة.
- بعد أي عملية تغير بيانات مشتركة، لا تنسى `ref.invalidate` للـ lookup والتقارير والداشبورد إذا كانت متأثرة.
- لا تستخدم `watch` داخل دالة تنفيذ زر إذا ما تحتاج إعادة بناء؛ استخدم `read`.
- أي Provider عليه `autoDispose` ينمسح عند مغادرة الصفحة، وهذا مفيد للتقارير والداشبورد حتى لا تبقى بيانات قديمة.
