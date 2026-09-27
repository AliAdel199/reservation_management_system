import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../programs/models/program_item.dart';
import '../../data/fundings_repository.dart';
import '../../models/funding_movement_item.dart';

class FundingMovementsDialog extends StatefulWidget {
  const FundingMovementsDialog({
    super.key,
    required this.repository,
    required this.programs,
    required this.sections,
  });

  final FundingsRepository repository;
  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;

  @override
  State<FundingMovementsDialog> createState() => _FundingMovementsDialogState();
}

class _FundingMovementsDialogState extends State<FundingMovementsDialog> {
  String? _programId;
  String? _sectionId;
  DateTime? _fromDate;
  DateTime? _toDate;
  late Future<List<FundingMovementItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FundingMovementItem>> _load() {
    return widget.repository.fetchMovements(
      programId: _programId,
      budgetSectionId: _sectionId,
      fromDate: _fromDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_fromDate!),
      toDate: _toDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_toDate!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final filteredSections = widget.sections
        .where(
          (section) =>
              _programId == null ? true : section.programId == _programId,
        )
        .toList();

    return AlertDialog(
      title: const Text('تقرير حركة التخصيصات'),
      content: SizedBox(
        width: 980,
        height: 620,
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _programId,
                    decoration: const InputDecoration(labelText: 'البرنامج'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      ...widget.programs.map(
                        (program) => DropdownMenuItem(
                          value: program.id,
                          child: Text(program.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _programId = value == '' ? null : value;
                      _sectionId = null;
                      _future = _load();
                    }),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sectionId,
                    decoration: const InputDecoration(labelText: 'الباب'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      ...filteredSections.map(
                        (section) => DropdownMenuItem(
                          value: section.id,
                          child: Text('${section.fullCode} - ${section.name}'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _sectionId = value == '' ? null : value;
                      _future = _load();
                    }),
                  ),
                ),
                _DateFilterButton(
                  label: _fromDate == null
                      ? 'من تاريخ'
                      : DateFormat('yyyy-MM-dd').format(_fromDate!),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _fromDate ?? DateTime.now(),
                    );
                    if (picked == null) return;
                    setState(() {
                      _fromDate = picked;
                      _future = _load();
                    });
                  },
                ),
                _DateFilterButton(
                  label: _toDate == null
                      ? 'إلى تاريخ'
                      : DateFormat('yyyy-MM-dd').format(_toDate!),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _toDate ?? DateTime.now(),
                    );
                    if (picked == null) return;
                    setState(() {
                      _toDate = picked;
                      _future = _load();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<FundingMovementItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('لا توجد حركات تخصيص ضمن الفلاتر الحالية.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isDecrease =
                          item.transactionType == 'adjustment_decrease' ||
                          item.transactionType == 'allocation_reversal';
                      return ListTile(
                        leading: Icon(
                          isDecrease
                              ? Icons.trending_down_outlined
                              : Icons.trending_up_outlined,
                          color: isDecrease
                              ? Theme.of(context).colorScheme.error
                              : const Color(0xFF1A7F5A),
                        ),
                        title: Text(
                          '${item.typeLabel} - ${currency.format(item.amount)}',
                        ),
                        subtitle: Text(
                          [
                                item.programName,
                                '${item.budgetSectionCode ?? '-'} - ${item.budgetSectionName ?? '-'}',
                                item.description,
                                item.createdByName == null
                                    ? null
                                    : 'بواسطة: ${item.createdByName}',
                              ]
                              .whereType<String>()
                              .where((e) => e.isNotEmpty)
                              .join('\n'),
                        ),
                        trailing: Text(
                          item.transactionDate.split('.').first,
                          textAlign: TextAlign.left,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.date_range_outlined),
      label: Text(label),
    );
  }
}
