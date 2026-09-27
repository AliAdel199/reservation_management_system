import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/dashboard_summary.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../widgets/summary_card.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_alerts_panel.dart';
import '../widgets/dashboard_section_cards.dart';
import '../widgets/dashboard_analytics_panel.dart';
import '../widgets/dashboard_summary.dart';

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
    final analyticsState = ref.watch(dashboardAnalyticsProvider);

    return AsyncValueView<DashboardSummary>(
      value: summaryState,
      onRetry: () => ref.invalidate(dashboardSummaryProvider),
      data: (summary) => _DashboardContent(
        summary: summary,
        sectionCardsState: sectionCardsState,
        analyticsState: analyticsState,
        selectedSectionLevel: _selectedSectionLevel,
        onSectionLevelChanged: (level) {
          setState(() => _selectedSectionLevel = level);
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.summary,
    required this.sectionCardsState,
    required this.analyticsState,
    required this.selectedSectionLevel,
    required this.onSectionLevelChanged,
  });

  final DashboardSummary summary;
  final AsyncValue<List<DashboardSectionCard>> sectionCardsState;
  final AsyncValue<DashboardAnalytics> analyticsState;
  final int selectedSectionLevel;
  final ValueChanged<int> onSectionLevelChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    final rows = <DashboardMetricRow>[
      DashboardMetricRow('إجمالي التخصيص', summary.totalAllocation),
      DashboardMetricRow('المحجوز', summary.totalReserved),
      DashboardMetricRow('المصروف', summary.totalSpent),
      DashboardMetricRow('المتبقي', summary.remainingBalance),
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة المتابعة المالية',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      // Text(
                      //   'هذه مرحلة تأسيسية. ابدأ بإضافة البرامج والأبواب لتصبح المنظومة حية فعلياً.',
                      //   style: Theme.of(context).textTheme.bodyMedium,
                      // ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/programs'),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('إدارة البرامج'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SummaryCard(
                  title: 'إجمالي التخصيص',
                  value: currency.format(summary.totalAllocation),
                  color: const Color(0xFF0D4A73),
                  icon: Icons.account_balance_wallet_outlined,
                  tooltip: 'فتح صفحة الأبواب والتخصيصات السنوية',
                  onTap: () => context.go('/budget-sections'),
                ),
                SummaryCard(
                  title: 'المحجوز',
                  value: currency.format(summary.totalReserved),
                  color: const Color(0xFFAC7B12),
                  icon: Icons.lock_outline,
                  tooltip: 'فتح صفحة الحجوزات',
                  onTap: () => context.go('/reservations'),
                ),
                SummaryCard(
                  title: 'المصروف',
                  value: currency.format(summary.totalSpent),
                  color: const Color(0xFF9F2D2D),
                  icon: Icons.payments_outlined,
                  tooltip: 'فتح صفحة الصرف',
                  onTap: () => context.go('/expenses'),
                ),
                SummaryCard(
                  title: 'المتبقي',
                  value: currency.format(summary.remainingBalance),
                  color: const Color(0xFF1A7F5A),
                  icon: Icons.savings_outlined,
                  tooltip: 'فتح تقرير ملخص الأبواب',
                  onTap: () => context.go('/reports'),
                ),
                SummaryCard(
                  title: 'أبواب بلا حركة',
                  value: '${summary.noMovementSectionsCount} باب',
                  color: const Color(0xFF596579),
                  icon: Icons.hourglass_empty_rounded,
                  tooltip: 'أبواب لديها تخصيص سنوي ولا يوجد عليها حجز أو صرف',
                  onTap: () => context.go('/reports?activity=no_movement'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (summary.balanceAlerts.isNotEmpty) ...[
              DashboardBalanceAlertsPanel(
                alerts: summary.balanceAlerts,
                formatter: currency,
              ),
              const SizedBox(height: 24),
            ],
            DashboardSectionCardsPanel(
              cardsState: sectionCardsState,
              formatter: currency,
              selectedLevel: selectedSectionLevel,
              onLevelChanged: onSectionLevelChanged,
            ),
            const SizedBox(height: 24),
            DashboardAnalyticsPanel(
              analyticsState: analyticsState,
              formatter: currency,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 1100;
                final chartWidth = isCompact
                    ? width
                    : ((width - 16) * 0.62).clamp(0, width);
                final gridWidth = isCompact
                    ? width
                    : ((width - 16) * 0.38).clamp(0, width);

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: chartWidth.toDouble(),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            height: 320,
                            child: DashboardSummaryChart(summary: summary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: gridWidth.toDouble(),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            height: 320,
                            child: DashboardSummaryGrid(
                              rows: rows,
                              formatter: currency,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
