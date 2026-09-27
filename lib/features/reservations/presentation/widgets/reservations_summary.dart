import 'package:flutter/material.dart';
import '../../models/reservation_item.dart';

class ReservationPageSummary {
  const ReservationPageSummary({
    required this.totalAmount,
    required this.totalSpent,
    required this.totalRemaining,
    required this.reservedCount,
    required this.approvedCount,
    required this.cancelledCount,
  });

  final double totalAmount;
  final double totalSpent;
  final double totalRemaining;
  final int reservedCount;
  final int approvedCount;
  final int cancelledCount;

  factory ReservationPageSummary.fromItems(List<ReservationItem> items) {
    final activeItems = items
        .where((item) => item.workflowStatus != 'cancelled')
        .toList();

    return ReservationPageSummary(
      totalAmount: activeItems.fold<double>(
        0,
        (sum, item) => sum + item.reservedAmount,
      ),
      totalSpent: activeItems.fold<double>(
        0,
        (sum, item) => sum + item.spentAmount,
      ),
      totalRemaining: activeItems.fold<double>(
        0,
        (sum, item) => sum + item.remainingAmount,
      ),
      reservedCount: activeItems
          .where(
            (item) =>
                item.workflowStatus == 'draft' ||
                item.workflowStatus == 'under_review',
          )
          .length,
      approvedCount: activeItems
          .where((item) => item.workflowStatus == 'approved')
          .length,
      cancelledCount: items
          .where((item) => item.workflowStatus == 'cancelled')
          .length,
    );
  }
}

class ReservationSummaryCard extends StatelessWidget {
  const ReservationSummaryCard({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E2EC)),
      ),
      child: Text("$title : $value", style: theme.textTheme.titleSmall),
    );
  }
}
