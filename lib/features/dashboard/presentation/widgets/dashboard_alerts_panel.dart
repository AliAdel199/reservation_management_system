import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/dashboard_summary.dart';

class DashboardBalanceAlertsPanel extends StatelessWidget {
  const DashboardBalanceAlertsPanel({
    super.key,
    required this.alerts,
    required this.formatter,
  });

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
