import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/dashboard_summary.dart';

class DashboardSectionCardsPanel extends StatelessWidget {
  const DashboardSectionCardsPanel({
    super.key,
    required this.cardsState,
    required this.formatter,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  final AsyncValue<List<DashboardSectionCard>> cardsState;
  final NumberFormat formatter;
  final int selectedLevel;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF0D4A73),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أبواب المستوى $selectedLevel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'اضغط على أي كارد لعرض حجوزاته وأبنائه',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المستوى',
                      isDense: true,
                    ),
                    items: List.generate(6, (index) => index + 1)
                        .map(
                          (level) => DropdownMenuItem<int>(
                            value: level,
                            child: Text('مستوى $level'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onLevelChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            cardsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('تعذر تحميل كاردات الأبواب: $error'),
              data: (cards) {
                if (cards.isEmpty) {
                  return Text(
                    'لا توجد أبواب في المستوى $selectedLevel تحتوي على أبناء ضمن السنة المفتوحة.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: cards.map((card) {
                    return _SectionDashboardCard(
                      card: card,
                      formatter: formatter,
                      onTap: () => context.go(
                        '/reservations?program_id=${Uri.encodeComponent(card.programId)}&budget_section_id=${Uri.encodeComponent(card.sectionId)}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDashboardCard extends StatelessWidget {
  const _SectionDashboardCard({
    required this.card,
    required this.formatter,
    required this.onTap,
  });

  final DashboardSectionCard card;
  final NumberFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 330,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD4E3ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F1F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_copy_outlined,
                      color: Color(0xFF0D4A73),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.sectionCode} - ${card.sectionName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          card.programName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                card.sectionPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6F7A),
                ),
              ),
              const SizedBox(height: 14),
              _CardMetricLine(
                label: 'تخصيص الأبناء',
                value: formatter.format(card.totalAllocation),
              ),
              const SizedBox(height: 8),
              _CardMetricLine(
                label: 'إجمالي المحجوز',
                value: formatter.format(card.totalReserved),
              ),
              const SizedBox(height: 8),
              _CardMetricLine(
                label: 'المتبقي',
                value: formatter.format(card.remainingBalance),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniPill('فروع: ${card.childrenCount}'),
                  const SizedBox(width: 8),
                  _MiniPill('نهائية: ${card.postableChildrenCount}'),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF0D4A73),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetricLine extends StatelessWidget {
  const _CardMetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D4A73),
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
