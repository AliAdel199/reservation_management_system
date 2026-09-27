import 'package:flutter/material.dart';
import '../../models/expense_item.dart';

class ExpensePageSummary {
  const ExpensePageSummary({
    required this.totalPaid,
    required this.activeCount,
    required this.cancelledAmount,
    required this.cancelledCount,
  });

  final double totalPaid;
  final int activeCount;
  final double cancelledAmount;
  final int cancelledCount;

  factory ExpensePageSummary.fromItems(List<ExpenseItem> items) {
    var totalPaid = 0.0;
    var activeCount = 0;
    var cancelledAmount = 0.0;
    var cancelledCount = 0;

    for (final item in items) {
      if (item.expenseStatus == 'cancelled') {
        cancelledAmount += item.amount;
        cancelledCount++;
      } else {
        totalPaid += item.amount;
        activeCount++;
      }
    }

    return ExpensePageSummary(
      totalPaid: totalPaid,
      activeCount: activeCount,
      cancelledAmount: cancelledAmount,
      cancelledCount: cancelledCount,
    );
  }
}

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF123B56),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
