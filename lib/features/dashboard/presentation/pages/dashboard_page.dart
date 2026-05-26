import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/models/dashboard_summary.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../widgets/summary_card.dart';
import '../providers/dashboard_providers.dart';

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

    final rows = <_MetricRow>[
      _MetricRow('إجمالي التخصيص', summary.totalAllocation),
      _MetricRow('المحجوز', summary.totalReserved),
      _MetricRow('المصروف', summary.totalSpent),
      _MetricRow('المتبقي', summary.remainingBalance),
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
              _BalanceAlertsPanel(
                alerts: summary.balanceAlerts,
                formatter: currency,
              ),
              const SizedBox(height: 24),
            ],
            _SectionCardsPanel(
              cardsState: sectionCardsState,
              formatter: currency,
              selectedLevel: selectedSectionLevel,
              onLevelChanged: onSectionLevelChanged,
            ),
            const SizedBox(height: 24),
            _AnalyticsPanel(
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
                            child: _SummaryChart(summary: summary),
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
                            child: _SummaryGrid(
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

class _BalanceAlertsPanel extends StatelessWidget {
  const _BalanceAlertsPanel({required this.alerts, required this.formatter});

  final List<DashboardBalanceAlert> alerts;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7E6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB7791F),
                ),
                const SizedBox(width: 8),
                Text(
                  'تنبيهات الرصيد',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7C4A03),
                  ),
                ),
                const Spacer(),
                Text(
                  'حد التنبيه: ${formatter.format(alerts.first.threshold)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7C4A03),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: alerts.map((alert) {
                final color = alert.isCritical
                    ? const Color(0xFF9F2D2D)
                    : const Color(0xFFB7791F);

                return Container(
                  width: 360,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            alert.isCritical
                                ? Icons.error_outline
                                : Icons.notifications_active_outlined,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'البرنامج: ${alert.programName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرصيد المتبقي: ${formatter.format(alert.remainingFunding)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCardsPanel extends StatelessWidget {
  const _SectionCardsPanel({
    required this.cardsState,
    required this.formatter,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  final AsyncValue<List<DashboardSectionCard>> cardsState;
  final NumberFormat formatter;
  final int selectedLevel;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF0D4A73),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أبواب المستوى $selectedLevel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'اضغط على أي كارد لعرض حجوزاته وأبنائه',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المستوى',
                      isDense: true,
                    ),
                    items: List.generate(6, (index) => index + 1)
                        .map(
                          (level) => DropdownMenuItem<int>(
                            value: level,
                            child: Text('مستوى $level'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onLevelChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            cardsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('تعذر تحميل كاردات الأبواب: $error'),
              data: (cards) {
                if (cards.isEmpty) {
                  return Text(
                    'لا توجد أبواب في المستوى $selectedLevel تحتوي على أبناء ضمن السنة المفتوحة.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: cards.map((card) {
                    return _SectionDashboardCard(
                      card: card,
                      formatter: formatter,
                      onTap: () => context.go(
                        '/reservations?program_id=${Uri.encodeComponent(card.programId)}&budget_section_id=${Uri.encodeComponent(card.sectionId)}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDashboardCard extends StatelessWidget {
  const _SectionDashboardCard({
    required this.card,
    required this.formatter,
    required this.onTap,
  });

  final DashboardSectionCard card;
  final NumberFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 330,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD4E3ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F1F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_copy_outlined,
                      color: Color(0xFF0D4A73),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.sectionCode} - ${card.sectionName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          card.programName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                card.sectionPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6F7A),
                ),
              ),
              const SizedBox(height: 14),
              _CardMetricLine(
                label: 'تخصيص الأبناء',
                value: formatter.format(card.totalAllocation),
              ),
              const SizedBox(height: 8),
              _CardMetricLine(
                label: 'إجمالي المحجوز',
                value: formatter.format(card.totalReserved),
              ),
              const SizedBox(height: 8),
              _CardMetricLine(
                label: 'المتبقي',
                value: formatter.format(card.remainingBalance),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniPill('فروع: ${card.childrenCount}'),
                  const SizedBox(width: 8),
                  _MiniPill('نهائية: ${card.postableChildrenCount}'),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF0D4A73),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetricLine extends StatelessWidget {
  const _CardMetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D4A73),
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.analyticsState,
    required this.formatter,
  });

  final AsyncValue<DashboardAnalytics> analyticsState;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, color: Color(0xFF0D4A73)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لوحات تحليل إضافية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'حسب البرنامج، الباب، الشهر، وأعلى أبواب صرفاً',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            analyticsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('تعذر تحميل التحليلات: $error'),
              data: (analytics) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isCompact = width < 1000;
                    final cardWidth = isCompact
                        ? width
                        : ((width - 16) / 2).clamp(360, width);

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth.toDouble(),
                          child: _AnalyticsChartCard(
                            title: 'حسب البرنامج',
                            subtitle: 'إجمالي التخصيص والحجز والصرف لكل برنامج',
                            emptyText: 'لا توجد برامج مالية للتحليل.',
                            items: analytics.programs,
                            formatter: formatter,
                            metric: _AnalyticsMetric.allocation,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth.toDouble(),
                          child: _AnalyticsChartCard(
                            title: 'حسب الباب',
                            subtitle: 'أكبر الأبواب حسب التخصيص السنوي',
                            emptyText: 'لا توجد أبواب مالية للتحليل.',
                            items: analytics.sections,
                            formatter: formatter,
                            metric: _AnalyticsMetric.allocation,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth.toDouble(),
                          child: _MonthlyAnalyticsCard(
                            monthly: analytics.monthly,
                            formatter: formatter,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth.toDouble(),
                          child: _AnalyticsChartCard(
                            title: 'أعلى أبواب صرفاً',
                            subtitle: 'الأبواب ذات المصروف الفعلي الأعلى',
                            emptyText: 'لا توجد مصروفات مسجلة بعد.',
                            items: analytics.topSpentSections,
                            formatter: formatter,
                            metric: _AnalyticsMetric.spent,
                            accent: const Color(0xFF9F2D2D),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _NoMovementSectionsCard(
                            sections: analytics.noMovementSections,
                            formatter: formatter,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _AnalyticsMetric { allocation, spent }

class _AnalyticsChartCard extends StatelessWidget {
  const _AnalyticsChartCard({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.items,
    required this.formatter,
    required this.metric,
    this.accent = const Color(0xFF0D4A73),
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final List<DashboardAnalyticsItem> items;
  final NumberFormat formatter;
  final _AnalyticsMetric metric;
  final Color accent;

  double _valueOf(DashboardAnalyticsItem item) {
    return switch (metric) {
      _AnalyticsMetric.allocation => item.totalAllocation,
      _AnalyticsMetric.spent => item.totalSpent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          if (visibleItems.isEmpty)
            SizedBox(height: 230, child: Center(child: Text(emptyText)))
          else ...[
            SizedBox(
              height: 210,
              child: _SimpleAnalyticsBarChart(
                items: visibleItems,
                valueOf: _valueOf,
                accent: accent,
                formatter: formatter,
              ),
            ),
            const SizedBox(height: 12),
            ...visibleItems
                .take(4)
                .map(
                  (item) => _AnalyticsLegendLine(
                    label: item.label,
                    value: formatter.format(_valueOf(item)),
                    color: accent,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _SimpleAnalyticsBarChart extends StatelessWidget {
  const _SimpleAnalyticsBarChart({
    required this.items,
    required this.valueOf,
    required this.accent,
    required this.formatter,
  });

  final List<DashboardAnalyticsItem> items;
  final double Function(DashboardAnalyticsItem item) valueOf;
  final Color accent;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final maxValue = items
        .map(valueOf)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final ceiling = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    return BarChart(
      BarChartData(
        maxY: ceiling,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.black.withValues(alpha: 0.06)),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(12),
            getTooltipColor: (_) => const Color(0xFF1E293B),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = items[group.x.toInt()];
              return BarTooltipItem(
                '${item.label}\n${formatter.format(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= items.length) {
                  return const SizedBox.shrink();
                }
                final label = items[index].label;
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: SizedBox(
                    width: 70,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: items.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: valueOf(entry.value),
                width: 28,
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.58)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyAnalyticsCard extends StatelessWidget {
  const _MonthlyAnalyticsCard({required this.monthly, required this.formatter});

  final List<DashboardMonthlyAnalyticsItem> monthly;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حسب الشهر',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'مقارنة المحجوز والمصروف شهرياً',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (monthly.isEmpty)
            const SizedBox(
              height: 230,
              child: Center(child: Text('لا توجد حركة شهرية بعد.')),
            )
          else
            SizedBox(
              height: 260,
              child: _MonthlyAnalyticsChart(
                monthly: monthly,
                formatter: formatter,
              ),
            ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: Color(0xFFAC7B12), label: 'محجوز'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF9F2D2D), label: 'مصروف'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyAnalyticsChart extends StatelessWidget {
  const _MonthlyAnalyticsChart({
    required this.monthly,
    required this.formatter,
  });

  final List<DashboardMonthlyAnalyticsItem> monthly;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final maxValue = monthly.fold<double>(0, (max, item) {
      final value = item.totalReserved > item.totalSpent
          ? item.totalReserved
          : item.totalSpent;
      return value > max ? value : max;
    });
    final ceiling = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    return BarChart(
      BarChartData(
        maxY: ceiling,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.black.withValues(alpha: 0.06)),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(12),
            getTooltipColor: (_) => const Color(0xFF1E293B),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = monthly[group.x.toInt()];
              final title = rodIndex == 0 ? 'محجوز' : 'مصروف';
              return BarTooltipItem(
                '${item.label}\n$title: ${formatter.format(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= monthly.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    monthly[index].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: monthly.asMap().entries.map((entry) {
          final item = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barsSpace: 5,
            barRods: [
              BarChartRodData(
                toY: item.totalReserved,
                width: 12,
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFAC7B12),
              ),
              BarChartRodData(
                toY: item.totalSpent,
                width: 12,
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF9F2D2D),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _NoMovementSectionsCard extends StatelessWidget {
  const _NoMovementSectionsCard({
    required this.sections,
    required this.formatter,
  });

  final List<DashboardNoMovementSection> sections;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.motion_photos_off_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أبواب بلا حركة مالية',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/reports?activity=no_movement'),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('فتح التقرير'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'كل الأبواب ذات التخصيص عليها حركة مالية أو لا توجد بيانات.',
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sections.map((section) {
                return Container(
                  width: 310,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE1E8EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${section.sectionCode} - ${section.sectionName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.programName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatter.format(section.totalAllocation),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF0D4A73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsLegendLine extends StatelessWidget {
  const _AnalyticsLegendLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          _LegendDot(color: color, label: ''),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SummaryChart extends StatelessWidget {
  const _SummaryChart({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      summary.totalAllocation,
      summary.totalReserved,
      summary.totalSpent,
      summary.remainingBalance,
    ];

    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),

      const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),

      const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),

      const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
    ];

    return BarChart(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,

      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,

        barTouchData: BarTouchData(
          enabled: true,

          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(12),

            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),

            getTooltipColor: (_) => const Color(0xff1E293B),

            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)} د.ع',

                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            },
          ),
        ),

        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,

          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.08),
              strokeWidth: 1,
            );
          },
        ),

        borderData: FlBorderData(show: false),

        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,

              getTitlesWidget: (value, meta) {
                const titles = ['تخصيص', 'حجز', 'صرف', 'متبقي'];

                if (value.toInt() < 0 || value.toInt() >= titles.length) {
                  return const SizedBox.shrink();
                }

                return SideTitleWidget(
                  meta: meta,
                  space: 8,

                  child: Text(
                    titles[value.toInt()],

                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        barGroups: items.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,

            barRods: [
              BarChartRodData(
                toY: entry.value,

                width: 34,

                borderRadius: BorderRadius.circular(14),

                gradient: gradients[entry.key],

                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: items.reduce((a, b) => a > b ? a : b),
                  color: Colors.black.withValues(alpha: 0.03),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.rows, required this.formatter});

  final List<_MetricRow> rows;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
      source: _SummaryDataSource(rows, formatter),
      columnWidthMode: ColumnWidthMode.fill,
      columns: [
        GridColumn(
          columnName: 'metric',
          label: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('المؤشر', overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        GridColumn(
          columnName: 'value',
          label: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('القيمة', overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow {
  const _MetricRow(this.title, this.value);

  final String title;
  final double value;
}

class _SummaryDataSource extends DataGridSource {
  _SummaryDataSource(List<_MetricRow> rows, NumberFormat formatter)
    : _rows = rows
          .map(
            (row) => DataGridRow(
              cells: [
                DataGridCell<String>(columnName: 'metric', value: row.title),
                DataGridCell<String>(
                  columnName: 'value',
                  value: formatter.format(row.value),
                ),
              ],
            ),
          )
          .toList();

  final List<DataGridRow> _rows;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(cell.value.toString()),
          ),
        );
      }).toList(),
    );
  }
}
