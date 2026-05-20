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

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(dashboardSummaryProvider);

    return AsyncValueView<DashboardSummary>(
      value: summaryState,
      onRetry: () => ref.invalidate(dashboardSummaryProvider),
      data: (summary) => _DashboardContent(summary: summary),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

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
                ),
                SummaryCard(
                  title: 'المحجوز',
                  value: currency.format(summary.totalReserved),
                  color: const Color(0xFFAC7B12),
                  icon: Icons.lock_outline,
                ),
                SummaryCard(
                  title: 'المصروف',
                  value: currency.format(summary.totalSpent),
                  color: const Color(0xFF9F2D2D),
                  icon: Icons.payments_outlined,
                ),
                SummaryCard(
                  title: 'المتبقي',
                  value: currency.format(summary.remainingBalance),
                  color: const Color(0xFF1A7F5A),
                  icon: Icons.savings_outlined,
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

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
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
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: items.asMap().entries.map((entry) {
          final colors = [
            const Color(0xFF0D4A73),
            const Color(0xFFAC7B12),
            const Color(0xFF9F2D2D),
            const Color(0xFF1A7F5A),
          ];
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                width: 36,
                borderRadius: BorderRadius.circular(12),
                color: colors[entry.key],
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
