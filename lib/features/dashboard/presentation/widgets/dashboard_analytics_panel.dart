import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/dashboard_summary.dart';
import 'dashboard_charts.dart';

class DashboardAnalyticsPanel extends StatelessWidget {
  const DashboardAnalyticsPanel({
    super.key,
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
              child: DashboardBarChart(
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
              child: DashboardMonthlyChart(
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
