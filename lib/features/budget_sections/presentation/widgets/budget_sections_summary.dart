import 'package:flutter/material.dart';
import '../../models/budget_section_item.dart';

class BudgetSectionsPageSummary {
  const BudgetSectionsPageSummary({
    required this.activeCount,
    required this.inactiveCount,
    required this.postableCount,
    required this.parentCount,
    required this.childrenCount,
    required this.postableAllocationTotal,
  });

  final int activeCount;
  final int inactiveCount;
  final int postableCount;
  final int parentCount;
  final int childrenCount;
  final double postableAllocationTotal;

  factory BudgetSectionsPageSummary.fromItems(List<BudgetSectionItem> items) {
    var activeCount = 0;
    var inactiveCount = 0;
    var postableCount = 0;
    var parentCount = 0;
    var childrenCount = 0;
    var postableAllocationTotal = 0.0;

    for (final item in items) {
      if (item.isActive) {
        activeCount++;
      } else {
        inactiveCount++;
      }

      childrenCount += item.childrenCount;
      if (item.isPostable) {
        postableCount++;
        postableAllocationTotal += item.allocatedAmount;
      } else {
        parentCount++;
      }
    }

    return BudgetSectionsPageSummary(
      activeCount: activeCount,
      inactiveCount: inactiveCount,
      postableCount: postableCount,
      parentCount: parentCount,
      childrenCount: childrenCount,
      postableAllocationTotal: postableAllocationTotal,
    );
  }
}

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
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
    final theme = Theme.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF123B56),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
