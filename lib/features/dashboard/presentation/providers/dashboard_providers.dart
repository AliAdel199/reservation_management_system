import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/models/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  // تعليق عربي: الداشبورد شاشة متابعة مباشرة، لذلك نعيد القراءة دورياً
  // ونمنع بقاء الأرقام القديمة في الكاش بعد عمليات الحجز والصرف.
  final timer = Stream<void>.periodic(const Duration(seconds: 10)).listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});

final dashboardSummaryByFiscalYearProvider = FutureProvider.autoDispose
    .family<DashboardSummary, String?>((ref, fiscalYearId) {
      return ref
          .watch(dashboardRepositoryProvider)
          .fetchSummary(fiscalYearId: fiscalYearId);
    });

final balanceAlertsProvider =
    FutureProvider.autoDispose<List<DashboardBalanceAlert>>((ref) async {
      // تعليق عربي: صفحة التنبيهات تحتاج تحديث مباشر مثل الداشبورد حتى تظهر المخاطر فوراً.
      final timer = Stream<void>.periodic(const Duration(seconds: 10)).listen((
        _,
      ) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      return ref.watch(dashboardRepositoryProvider).fetchBalanceAlerts();
    });

final dashboardSectionCardsProvider = FutureProvider.autoDispose
    .family<List<DashboardSectionCard>, int>((ref, level) async {
      final timer = Stream<void>.periodic(const Duration(seconds: 10)).listen((
        _,
      ) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      return ref
          .watch(dashboardRepositoryProvider)
          .fetchSectionCards(level: level);
    });

final dashboardAnalyticsProvider =
    FutureProvider.autoDispose<DashboardAnalytics>((ref) async {
      final timer = Stream<void>.periodic(const Duration(seconds: 10)).listen((
        _,
      ) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      return ref.watch(dashboardRepositoryProvider).fetchAnalytics();
    });
