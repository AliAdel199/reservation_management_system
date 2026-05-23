# دليل Riverpod في نظام إدارة الحجوزات المالية

هذا الملف يشرح Riverpod بالطريقة المستخدمة داخل المشروع الحالي، حتى يكون مرجع سريع عند التعديل اليدوي أو إضافة صفحات جديدة.

## 1. شنو هو Riverpod؟

Riverpod هو نظام لإدارة الحالة والاعتمادات داخل Flutter.

يعني بدل ما كل صفحة تنشئ `ApiClient` و `Repository` وتحفظ التحميل والخطأ والبيانات بنفسها، نخلي Riverpod يرتب الربط بهذا الشكل:

```text
UI Page
  -> Controller / Provider
  -> Repository
  -> ApiClient
  -> Backend API
```

الصفحة فقط تراقب الحالة:

```dart
final state = ref.watch(reservationsControllerProvider);
```

وإذا البيانات تغيرت، Riverpod يعيد بناء الجزء المحتاج تحديث.

## 2. ProviderScope

أول نقطة مهمة موجودة في:

```text
lib/main.dart
```

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ReservationManagementApp()));
}
```

`ProviderScope` هو الحاوية الرئيسية لكل Providers داخل التطبيق.

بدونه، أوامر مثل `ref.watch` و `ref.read` لا تعمل.

اعتبره ذاكرة Riverpod العامة للتطبيق.

## 3. Provider العادي

نستخدم `Provider` لإنشاء خدمة أو Repository لا يحتاج حالة تحميل.

مثال من:

```text
lib/features/auth/presentation/providers/auth_providers.dart
```

```dart
final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(appStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(appStorageProvider),
  ),
);
```

المعنى:

- `appStorageProvider` ينشئ التخزين المحلي.
- `apiClientProvider` ينشئ API client ويعتمد على التخزين حتى يقرأ التوكن.
- `authRepositoryProvider` ينشئ repository المصادقة ويعتمد على `ApiClient` و `AppStorage`.

إذا تريد تضيف Repository جديد، النمط يكون:

```dart
final myRepositoryProvider = Provider<MyRepository>(
  (ref) => MyRepository(ref.watch(apiClientProvider)),
);
```

## 4. AsyncNotifierProvider

هذا أهم نوع مستخدم عندنا للصفحات التي تحتاج:

- تحميل بيانات من API.
- حفظ فلاتر.
- إضافة.
- تعديل.
- حذف.
- تحديث الصفحة بعد العملية.

مثال من:

```text
lib/features/auth/presentation/controllers/auth_controller.dart
```

```dart
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
```

هذا يعني:

- اسم Provider هو `authControllerProvider`.
- Controller هو `AuthController`.
- الحالة النهائية هي `AuthSession?`.
- لأنها async، الحالة تكون واحدة من:
  - `AsyncLoading`
  - `AsyncError`
  - `AsyncData<AuthSession?>`

داخل Controller:

```dart
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return ref.read(authRepositoryProvider).restoreSession();
  }
}
```

دالة `build()` تشتغل أول مرة يحتاج أحد هذا Provider.

هنا ترجع الجلسة المحفوظة إذا المستخدم سبق وسجل دخول.

## 5. state داخل AsyncNotifier

داخل أي `AsyncNotifier` توجد متغير مهم اسمه `state`.

مثال login:

```dart
Future<void> login({
  required String identity,
  required String password,
}) async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(
    () => ref
        .read(authRepositoryProvider)
        .login(identity: identity, password: password),
  );
}
```

المعنى:

1. خلي الحالة تحميل.
2. نفذ API login.
3. إذا نجح، Riverpod يجعلها `AsyncData`.
4. إذا فشل، Riverpod يجعلها `AsyncError`.

هذا يقلل كود try/catch داخل الواجهات.

## 6. ref.watch

`ref.watch` يعني:

راقب هذا Provider، وإذا تغير حدث الواجهة.

مثال من:

```text
lib/features/dashboard/presentation/pages/dashboard_page.dart
```

```dart
final summaryState = ref.watch(dashboardSummaryProvider);
```

إذا تغيرت بيانات الداشبورد، الصفحة يعاد بناؤها تلقائياً.

نستخدم `watch` غالباً داخل `build()`.

## 7. ref.read

`ref.read` يعني:

اقرأ Provider مرة واحدة بدون مراقبة مستمرة.

نستخدمه غالباً داخل أزرار أو دوال تنفيذ.

مثال:

```dart
await ref.read(budgetSectionsControllerProvider.notifier).create(payload);
```

هنا لا نريد مراقبة Controller، فقط نريد استدعاء دالة `create`.

قاعدة عملية:

```text
watch = للعرض والمراقبة
read = للأفعال مثل حفظ، حذف، اعتماد، تسجيل دخول
```

## 8. ref.invalidate

`ref.invalidate` يعني:

امسح كاش Provider وخليه يعيد التحميل.

مثال من:

```text
lib/features/budget_sections/presentation/controllers/budget_sections_controller.dart
```

```dart
Future<void> create(Map<String, dynamic> payload) async {
  await _repository.createBudgetSection(payload);
  await refresh();
  ref.invalidate(allBudgetSectionsLookupProvider);
}
```

المعنى:

1. أضف الباب عبر API.
2. حدث صفحة الأبواب.
3. امسح كاش قائمة الأبواب العامة حتى القوائم المنسدلة تتحدث.

مهم تستخدم `invalidate` إذا عدلت بيانات Provider ثاني يعتمد على نفس المصدر.

## 9. FutureProvider

نستخدم `FutureProvider` عندما نحتاج تحميل بيانات فقط، بدون عمليات كثيرة.

مثال:

```dart
final allBudgetSectionsLookupProvider = FutureProvider<List<BudgetSectionItem>>(
  (ref) async {
    final repository = ref.watch(budgetSectionsRepositoryProvider);
    final result = await repository.fetchBudgetSections(
      search: '',
      programId: null,
      fiscalYearId: null,
      budgetTypeId: null,
      page: 1,
      pageSize: 1000,
    );
    return result.items;
  },
);
```

هذا يستخدم لقوائم الأبواب المنسدلة.

لا يحتاج Controller كامل لأنه فقط يقرأ بيانات.

## 10. FutureProvider.family

`family` يعني Provider يأخذ parameter.

مثال من الداشبورد:

```dart
final dashboardSectionCardsProvider = FutureProvider.autoDispose
    .family<List<DashboardSectionCard>, int>((ref, level) async {
  return ref
      .watch(dashboardRepositoryProvider)
      .fetchSectionCards(level: level);
});
```

الاستخدام:

```dart
ref.watch(dashboardSectionCardsProvider(3));
ref.watch(dashboardSectionCardsProvider(4));
```

كل مستوى له كاش منفصل.

هذا مفيد عندما نفس API يحتاج قيمة مختلفة مثل:

- level
- id
- fiscalYearId
- filter

## 11. autoDispose

`autoDispose` يعني:

إذا الصفحة تركت Provider وما عاد أحد يستخدمه، Riverpod ينظفه من الذاكرة.

مثال:

```dart
final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  ...
});
```

مفيد للصفحات التي تعمل تحديث تلقائي حتى لا يبقى Timer شغال بالخلفية بعد مغادرة الصفحة.

## 12. التحديث التلقائي

في الداشبورد والتنبيهات استخدمنا Timer داخل Provider:

```dart
final timer = Stream<void>.periodic(const Duration(seconds: 10)).listen((_) {
  ref.invalidateSelf();
});
ref.onDispose(timer.cancel);
```

المعنى:

- كل 10 ثواني Provider يعيد تحميل نفسه.
- عند إغلاق الصفحة، Riverpod ينادي `onDispose`.
- `timer.cancel` يوقف التحديث حتى لا يبقى يعمل بالخلفية.

هذا مستخدم في:

```text
lib/features/dashboard/presentation/providers/dashboard_providers.dart
```

## 13. AsyncValue

لأن البيانات تأتي من API، Riverpod لا يرجع البيانات مباشرة.

يرجع `AsyncValue`.

يعني عندك 3 حالات:

- loading
- error
- data

بدل ما نكتبها بكل صفحة، عندنا Widget مساعد:

```text
lib/shared/widgets/async_value_view.dart
```

الاستخدام:

```dart
return AsyncValueView(
  value: budgetSectionsState,
  data: (state) {
    return ...;
  },
);
```

هذا يوحد طريقة عرض التحميل والخطأ وإعادة المحاولة.

## 14. ConsumerWidget

إذا الصفحة لا تحتاج `setState` داخلي، نستخدم `ConsumerWidget`.

مثال من:

```text
lib/core/app/app.dart
```

```dart
class ReservationManagementApp extends ConsumerWidget {
  const ReservationManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
    );
  }
}
```

الفرق عن `StatelessWidget` أن `ConsumerWidget` يعطيك `WidgetRef ref`.

## 15. ConsumerStatefulWidget

إذا الصفحة تحتاج `setState` داخلي بالإضافة إلى Riverpod، نستخدم `ConsumerStatefulWidget`.

مثال من:

```text
lib/features/dashboard/presentation/pages/dashboard_page.dart
```

```dart
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedSectionLevel = 3;

  @override
  Widget build(BuildContext context) {
    final summaryState = ref.watch(dashboardSummaryProvider);
    final sectionCardsState = ref.watch(
      dashboardSectionCardsProvider(_selectedSectionLevel),
    );
    ...
  }
}
```

هنا استخدمنا:

- `setState` لتغيير المستوى المختار محلياً.
- `ref.watch` لجلب بيانات الداشبورد من Riverpod.

## 16. نمط تنظيم Feature عندنا

كل وحدة تقريباً منظمة بهذا الشكل:

```text
features/reservations/
  models/
    reservation_item.dart

  data/
    reservations_repository.dart

  presentation/controllers/
    reservations_controller.dart

  presentation/pages/
    reservations_page.dart
```

الدور:

- `model`: يمثل JSON القادم من API.
- `repository`: يتكلم مع API باستخدام Dio.
- `controller`: يدير حالة الصفحة والفلاتر والعمليات.
- `page`: تعرض الواجهة وتستعمل `ref.watch` و `ref.read`.

## 17. مثال كامل: صفحة الأبواب

في الصفحة:

```dart
final budgetSectionsState = ref.watch(budgetSectionsControllerProvider);
```

عند الضغط على حفظ:

```dart
await ref.read(budgetSectionsControllerProvider.notifier).create(payload);
```

في Controller:

```dart
Future<void> create(Map<String, dynamic> payload) async {
  await _repository.createBudgetSection(payload);
  await refresh();
  ref.invalidate(allBudgetSectionsLookupProvider);
}
```

في Repository:

```dart
await _apiClient.instance.post('/budget-sections', data: payload);
```

التسلسل الكامل:

```text
Button
  -> ref.read(controller.notifier).create(payload)
  -> Controller
  -> Repository
  -> ApiClient
  -> Backend API
  -> refresh
  -> UI تتحدث تلقائياً
```

## 18. الفرق بين setState و Riverpod

استخدم `setState` عندما تكون الحالة صغيرة وخاصة بنفس الصفحة فقط.

أمثلة:

- اختيار tab مؤقت.
- فتح أو غلق عنصر في الواجهة.
- اختيار مستوى عرض محلي.

استخدم Riverpod عندما تكون الحالة:

- قادمة من API.
- تحتاج loading/error.
- مشتركة بين أكثر من صفحة.
- تحتاج تحديث بعد عمليات create/update/delete.
- تحتاج كاش أو إعادة تحميل.

## 19. متى أستخدم كل نوع؟

استخدم `Provider` إذا تريد خدمة أو Repository.

استخدم `FutureProvider` إذا تريد تحميل بيانات فقط.

استخدم `FutureProvider.family` إذا التحميل يحتاج parameter.

استخدم `AsyncNotifierProvider` إذا عندك صفحة كاملة فيها بيانات وعمليات وفلاتر.

استخدم `setState` للأشياء الصغيرة داخل نفس الصفحة.

## 20. أخطاء شائعة لازم تنتبه لها

لا تستخدم `ref.watch` داخل دالة زر. استخدم `ref.read`.

لا تنس `ref.invalidate` بعد تعديل بيانات تؤثر على Provider ثاني.

لا تجعل الصفحة تتعامل مع Dio مباشرة.

لا تجعل Repository يعرف تفاصيل الواجهة.

لا تخزن بيانات API المهمة داخل Widget إذا أكثر من صفحة تحتاجها.

لا تترك Timer بدون `ref.onDispose(timer.cancel)`.

## 21. إضافة صفحة جديدة بنمط المشروع

مثال مختصر:

```dart
final myRepositoryProvider = Provider<MyRepository>(
  (ref) => MyRepository(ref.watch(apiClientProvider)),
);

final myControllerProvider =
    AsyncNotifierProvider<MyController, MyState>(MyController.new);

class MyController extends AsyncNotifier<MyState> {
  @override
  Future<MyState> build() async {
    return _fetch();
  }

  Future<MyState> _fetch() async {
    final result = await ref.read(myRepositoryProvider).fetchItems();
    return MyState(result: result);
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await ref.read(myRepositoryProvider).create(payload);
    state = await AsyncValue.guard(_fetch);
  }
}
```

في الصفحة:

```dart
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);

    return AsyncValueView(
      value: state,
      data: (data) => Text('Loaded'),
    );
  }
}
```

## 22. خلاصة عملية

إذا فهمت هذه المفاتيح، فأنت ماسك أغلب Riverpod في المشروع:

```text
Provider = إنشاء خدمة أو Repository
FutureProvider = تحميل بيانات فقط
FutureProvider.family = تحميل بيانات مع parameter
AsyncNotifierProvider = Controller كامل للصفحة
ref.watch = راقب وحدث الواجهة
ref.read = نفذ فعل مرة واحدة
ref.invalidate = امسح الكاش وأعد التحميل
autoDispose = نظف Provider عند ترك الصفحة
AsyncValue = loading/error/data
```

Riverpod في هذا النظام هو الغراء الذي يخلي الواجهة، الـ API، والبيانات تتحرك بشكل منظم وقابل للصيانة.
