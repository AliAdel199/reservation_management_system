import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/dashboard_summary.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

class BalanceAlertsPage extends ConsumerWidget {
  const BalanceAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(balanceAlertsProvider);

    return Padding(
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
                      'التنبيهات',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متابعة الأبواب التي وصل رصيدها أو تمويلها إلى حد الخطر حتى تتم معالجة الموقف قبل توقف الصرف.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(balanceAlertsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: AsyncValueView<List<DashboardBalanceAlert>>(
                value: alertsState,
                onRetry: () => ref.invalidate(balanceAlertsProvider),
                data: (alerts) {
                  if (alerts.isEmpty) return const _EmptyAlerts();
                  return _AlertsList(alerts: alerts);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.alerts});

  final List<DashboardBalanceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _AlertCard(alert: alert, formatter: formatter);
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: alerts.length,
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.formatter});

  final DashboardBalanceAlert alert;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.isCritical;
    final color = isCritical ? Colors.red.shade700 : Colors.orange.shade800;
    final background = isCritical ? Colors.red.shade50 : Colors.orange.shade50;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(
              isCritical
                  ? Icons.error_outline
                  : Icons.notification_important_outlined,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(label: 'البرنامج', value: alert.programName),
                    _InfoChip(
                      label: 'الباب',
                      value: '${alert.sectionCode} - ${alert.sectionName}',
                    ),
                    _InfoChip(
                      label: 'الرصيد الحالي',
                      value: formatter.format(alert.remainingFunding),
                    ),
                    _InfoChip(
                      label: 'حد التنبيه',
                      value: formatter.format(alert.threshold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 56, color: Colors.green.shade700),
          const SizedBox(height: 14),
          Text(
            'لا توجد تنبيهات حالياً',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'كل الأرصدة أعلى من حد التنبيه المحدد.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
