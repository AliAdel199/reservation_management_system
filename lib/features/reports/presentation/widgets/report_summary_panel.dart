import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/section_summary_item.dart';

class ReportSummaryPanel extends StatelessWidget {
  const ReportSummaryPanel({
    super.key,
    required this.items,
    required this.formatter,
    required this.selectedMonth,
  });

  final List<SectionSummaryItem> items;
  final NumberFormat formatter;
  final int selectedMonth;

  @override
  Widget build(BuildContext context) {
    final totalAllocation = items.fold<double>(
      0,
      (sum, item) => sum + item.allocatedAmount,
    );
    final totalReserved = items.fold<double>(
      0,
      (sum, item) => sum + item.totalReserved,
    );
    final totalSpent = items.fold<double>(
      0,
      (sum, item) => sum + item.totalSpent,
    );
    final totalPeriodDisposable = items.fold<double>(
      0,
      (sum, item) => sum + item.effectivePeriodDisposable(selectedMonth),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _SummaryChip(label: 'السجلات', value: items.length.toString()),
          _SummaryChip(
            label: 'التخصيص',
            value: formatter.format(totalAllocation),
          ),
          _SummaryChip(
            label: 'المحجوز',
            value: formatter.format(totalReserved),
          ),
          _SummaryChip(label: 'المصروف', value: formatter.format(totalSpent)),
          _SummaryChip(
            label: 'القابل للصرف',
            value: formatter.format(totalPeriodDisposable),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: const Color(0xFFEFF6FA),
      side: const BorderSide(color: Color(0xFFC9D6DF)),
    );
  }
}
