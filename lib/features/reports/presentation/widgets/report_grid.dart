import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/section_summary_item.dart';
import 'report_table_config.dart';

class SectionSummaryDataSource extends DataGridSource {
  SectionSummaryDataSource({
    required this.items,
    required this.formatter,
    required this.selectedMonth,
    required this.grouping,
    required this.columns,
  });

  final List<SectionSummaryItem> items;
  final NumberFormat formatter;
  final int selectedMonth;
  final ReportGrouping grouping;
  final List<ReportColumn> columns;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: columns
              .map(
                (column) => DataGridCell<SectionSummaryItem>(
                  columnName: column.key,
                  value: item,
                ),
              )
              .toList(),
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as SectionSummaryItem;
    return DataGridRowAdapter(
      cells: columns
          .map((column) => _GridCell(_cellText(column, item)))
          .toList(),
    );
  }

  String _cellText(ReportColumn column, SectionSummaryItem item) {
    switch (column) {
      case ReportColumn.program:
        return item.programName;
      case ReportColumn.section:
        return grouping == ReportGrouping.byProgram
            ? item.sectionName
            : '${item.sectionCode} - ${item.sectionName}';
      case ReportColumn.allocation:
        return formatter.format(item.allocatedAmount);
      case ReportColumn.reserved:
        return formatter.format(item.totalReserved);
      case ReportColumn.unreserved:
        return formatter.format(item.remainingAllocation);
      case ReportColumn.spent:
        return formatter.format(item.totalSpent);
      case ReportColumn.remainingBySpent:
        return formatter.format(item.effectiveRemainingBySpent());
      case ReportColumn.monthlyQuota:
        return formatter.format(item.effectiveMonthlyQuota());
      case ReportColumn.periodAllowed:
        return formatter.format(item.effectivePeriodAllowed(selectedMonth));
      case ReportColumn.periodDisposable:
        return formatter.format(item.effectivePeriodDisposable(selectedMonth));
      case ReportColumn.rates:
        return 'حجز ${item.reservationRate.toStringAsFixed(1)}% / صرف ${item.spendingRate.toStringAsFixed(1)}%';
    }
  }
}

class ReportGridHeader extends StatelessWidget {
  const ReportGridHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class ReportHorizontalScrollHint extends StatelessWidget {
  const ReportHorizontalScrollHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.swap_horiz, size: 18, color: Color(0xFF52616F)),
          SizedBox(width: 6),
          Text(
            'اسحب الجدول أفقياً لعرض بقية أعمدة المتابعة',
            style: TextStyle(color: Color(0xFF52616F), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
