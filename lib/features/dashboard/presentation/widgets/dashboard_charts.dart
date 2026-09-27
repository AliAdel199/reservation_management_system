import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/dashboard_summary.dart';

class DashboardBarChart extends StatelessWidget {
  const DashboardBarChart({
    super.key,
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

class DashboardMonthlyChart extends StatelessWidget {
  const DashboardMonthlyChart({
    super.key,
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
