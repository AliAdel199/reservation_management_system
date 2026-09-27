import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../shared/models/dashboard_summary.dart';

class DashboardSummaryChart extends StatelessWidget {
  const DashboardSummaryChart({super.key, required this.summary});

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

class DashboardSummaryGrid extends StatelessWidget {
  const DashboardSummaryGrid({
    super.key,
    required this.rows,
    required this.formatter,
  });

  final List<DashboardMetricRow> rows;
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

class DashboardMetricRow {
  const DashboardMetricRow(this.title, this.value);

  final String title;
  final double value;
}

class _SummaryDataSource extends DataGridSource {
  _SummaryDataSource(List<DashboardMetricRow> rows, NumberFormat formatter)
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
