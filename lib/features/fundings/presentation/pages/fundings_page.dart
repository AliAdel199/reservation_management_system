import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../data/fundings_repository.dart';
import '../../models/funding_item.dart';
import '../../models/funding_movement_item.dart';
import '../controllers/fundings_controller.dart';

class FundingsPage extends ConsumerStatefulWidget {
  const FundingsPage({super.key});

  @override
  ConsumerState<FundingsPage> createState() => _FundingsPageState();
}

class _FundingsPageState extends ConsumerState<FundingsPage> {
  final _searchController = TextEditingController();
  String? _selectedProgramId;
  String? _selectedBudgetSectionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fundingsState = ref.watch(fundingsControllerProvider);
    final programsLookup = ref.watch(programLookupProvider);
    final budgetSectionsLookup = ref.watch(allBudgetSectionsLookupProvider);
    final fiscalYearsLookup = ref.watch(fiscalYearsLookupProvider);
    final activeFiscalYear = _activeFiscalYear(fiscalYearsLookup.asData?.value);

    ref.listen(fundingsControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    final availableSections =
        budgetSectionsLookup.asData?.value
            .where(
              (section) => _selectedProgramId == null
                  ? true
                  : section.programId == _selectedProgramId,
            )
            .toList() ??
        const <BudgetSectionItem>[];

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
                      'التخصيصات المالية',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة التخصيصات المالية وربطها بالبرامج والأبواب مع تسجيلها داخل Ledger المالي.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: budgetSectionsLookup.hasValue
                        ? () => _openMovementsReport(
                            programsLookup.asData?.value ?? const [],
                            budgetSectionsLookup.requireValue,
                          )
                        : null,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('تقرير الحركة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: budgetSectionsLookup.hasValue
                        ? () => _openTransferDialog(
                            budgetSectionsLookup.requireValue,
                          )
                        : null,
                    icon: const Icon(Icons.swap_horiz_outlined),
                    label: const Text('مناقلة'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        programsLookup.hasValue && budgetSectionsLookup.hasValue
                        ? () => _openCreateDialog(
                            programsLookup.requireValue,
                            budgetSectionsLookup.requireValue,
                            activeFiscalYear: activeFiscalYear,
                          )
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تخصيص'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالمرجع أو البرنامج أو الباب',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 250,
                child: programsLookup.when(
                  data: (programs) => DropdownButtonFormField<String>(
                    initialValue: _selectedProgramId,
                    decoration: const InputDecoration(labelText: 'البرنامج'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('كل البرامج'),
                      ),
                      ...programs.map(
                        (program) => DropdownMenuItem<String>(
                          value: program.id,
                          child: Text(program.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedProgramId = value == '' ? null : value;
                      _selectedBudgetSectionId = null;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('تعذر تحميل البرامج'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBudgetSectionId,
                  decoration: const InputDecoration(labelText: 'الباب'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('كل الأبواب'),
                    ),
                    ...availableSections.map(
                      (section) => DropdownMenuItem<String>(
                        value: section.id,
                        child: Text('${section.code} - ${section.name}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedBudgetSectionId = value == '' ? null : value;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _applyFilters,
                child: const Text('تطبيق'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: fundingsState,
                onRetry: () =>
                    ref.read(fundingsControllerProvider.notifier).refresh(),
                data: (state) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: _FundingsDataSource(
                          items: state.result.items,
                          formatter: NumberFormat.currency(
                            locale: 'ar_IQ',
                            symbol: 'د.ع',
                            decimalDigits: 0,
                          ),
                          onEdit: (item) async {
                            try {
                              if (!programsLookup.hasValue ||
                                  !budgetSectionsLookup.hasValue) {
                                return;
                              }
                              await _openEditDialog(
                                programsLookup.requireValue,
                                budgetSectionsLookup.requireValue,
                                item,
                              );
                            } catch (error) {
                              if (!mounted) return;
                              _showError(_friendlyFundingError(error));
                            }
                          },
                        ),
                        columnWidthMode: ColumnWidthMode.auto,
                        columns: [
                          GridColumn(
                            columnName: 'reference',
                            label: _GridHeader('مرجع التخصيص'),
                          ),
                          GridColumn(
                            columnName: 'program',
                            label: _GridHeader('البرنامج'),
                          ),
                          GridColumn(
                            columnName: 'section',
                            label: _GridHeader('الباب'),
                          ),
                          GridColumn(
                            columnName: 'year',
                            label: _GridHeader('السنة'),
                          ),
                          GridColumn(
                            columnName: 'initial_amount',
                            label: _GridHeader('التخصيص البدائي'),
                          ),
                          GridColumn(
                            columnName: 'current_amount',
                            label: _GridHeader('التخصيص الحالي'),
                          ),
                          GridColumn(
                            columnName: 'reserved_amount',
                            label: _GridHeader('المحجوز'),
                          ),
                          GridColumn(
                            columnName: 'spent_amount',
                            label: _GridHeader('المصروف'),
                          ),
                          GridColumn(
                            columnName: 'available_amount',
                            label: _GridHeader('المتبقي المتاح'),
                          ),
                          GridColumn(
                            columnName: 'actions',
                            label: _GridHeader('إجراءات'),
                          ),
                        ],
                      ),
                    ),
                    _PaginationBar(
                      page: state.result.pagination.page,
                      totalPages: state.result.pagination.totalPages,
                      total: state.result.pagination.total,
                      onPrevious: state.result.pagination.page > 1
                          ? () => ref
                                .read(fundingsControllerProvider.notifier)
                                .changePage(state.result.pagination.page - 1)
                          : null,
                      onNext:
                          state.result.pagination.page <
                              state.result.pagination.totalPages
                          ? () => ref
                                .read(fundingsControllerProvider.notifier)
                                .changePage(state.result.pagination.page + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections, {
    int? activeFiscalYear,
  }) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FundingDialog(
        programs: programs,
        sections: sections,
        activeFiscalYear: activeFiscalYear,
      ),
    );

    if (payload == null || !mounted) return;
    try {
      await ref.read(fundingsControllerProvider.notifier).create(payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تمت إضافة التخصيص بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  Future<void> _openEditDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
    FundingItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FundingDialog(
        programs: programs,
        sections: sections,
        initialValue: item,
      ),
    );

    if (payload == null || !mounted) return;
    try {
      await ref
          .read(fundingsControllerProvider.notifier)
          .updateFunding(item.id, payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تم تحديث التخصيص بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  int? _activeFiscalYear(List<FiscalYearItem>? fiscalYears) {
    if (fiscalYears == null) return null;
    for (final fiscalYear in fiscalYears) {
      if (fiscalYear.isActive) return fiscalYear.year;
    }
    return null;
  }

  Future<void> _openTransferDialog(List<BudgetSectionItem> sections) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TransferAllocationDialog(sections: sections),
    );

    if (payload == null || !mounted) return;
    try {
      await ref
          .read(fundingsControllerProvider.notifier)
          .transferAllocation(payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تمت المناقلة بين التخصيصات بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  Future<void> _openMovementsReport(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _FundingMovementsDialog(
        repository: ref.read(fundingsRepositoryProvider),
        programs: programs,
        sections: sections,
      ),
    );
  }

  void _applyFilters() {
    ref
        .read(fundingsControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          programId: _selectedProgramId,
          budgetSectionId: _selectedBudgetSectionId,
        );
  }

  String _friendlyFundingError(Object error) {
    if (error is AppException) {
      if (error.code == 'FUNDING_REFERENCE_EXISTS') {
        return 'مرجع التخصيص مستخدم مسبقاً. غيّر المرجع أو تأكد من السجل الصحيح.';
      }
      return error.message;
    }
    return error.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TransferAllocationDialog extends StatefulWidget {
  const _TransferAllocationDialog({required this.sections});

  final List<BudgetSectionItem> sections;

  @override
  State<_TransferAllocationDialog> createState() =>
      _TransferAllocationDialogState();
}

class _TransferAllocationDialogState extends State<_TransferAllocationDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final sections = widget.sections
        .where((section) => section.isPostable && section.isActive)
        .toList();

    return AlertDialog(
      title: const Text('مناقلة بين التخصيصات'),
      content: SizedBox(
        width: 620,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'reference': 'TR-${DateTime.now().millisecondsSinceEpoch}',
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderDropdown<String>(
                name: 'from_budget_section_id',
                decoration: const InputDecoration(labelText: 'من باب'),
                items: sections
                    .map(
                      (section) => DropdownMenuItem(
                        value: section.id,
                        child: Text(
                          '${section.fullCode} - ${section.name} (${currency.format(section.allocatedAmount)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'to_budget_section_id',
                decoration: const InputDecoration(labelText: 'إلى باب'),
                items: sections
                    .map(
                      (section) => DropdownMenuItem(
                        value: section.id,
                        child: Text(
                          '${section.fullCode} - ${section.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(labelText: 'مبلغ المناقلة'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'reference',
                decoration: const InputDecoration(labelText: 'مرجع المناقلة'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'notes',
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('تنفيذ المناقلة')),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    if (values['from_budget_section_id'] == values['to_budget_section_id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن المناقلة لنفس الباب.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'from_budget_section_id': values['from_budget_section_id']?.toString(),
      'to_budget_section_id': values['to_budget_section_id']?.toString(),
      'amount': double.parse(values['amount'].toString()),
      'reference': values['reference']?.toString().trim(),
      'notes': values['notes']?.toString().trim(),
    });
  }
}

class _FundingMovementsDialog extends StatefulWidget {
  const _FundingMovementsDialog({
    required this.repository,
    required this.programs,
    required this.sections,
  });

  final FundingsRepository repository;
  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;

  @override
  State<_FundingMovementsDialog> createState() =>
      _FundingMovementsDialogState();
}

class _FundingMovementsDialogState extends State<_FundingMovementsDialog> {
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

class _FundingDialog extends StatefulWidget {
  const _FundingDialog({
    required this.programs,
    required this.sections,
    this.initialValue,
    this.activeFiscalYear,
  });

  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;
  final FundingItem? initialValue;
  final int? activeFiscalYear;

  @override
  State<_FundingDialog> createState() => _FundingDialogState();
}

class _FundingDialogState extends State<_FundingDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _programId;

  @override
  void initState() {
    super.initState();
    _programId = widget.initialValue?.programId;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;
    final availableSections = widget.sections
        .where(
          (section) =>
              _programId == null ? true : section.programId == _programId,
        )
        .toList();

    return AlertDialog(
      title: Text(item == null ? 'إضافة تخصيص مالي' : 'تعديل تخصيص مالي'),
      content: SizedBox(
        width: 560,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'program_id': item?.programId,
            'budget_section_id': item?.budgetSectionId,
            'funding_reference': item?.fundingReference,
            'fiscal_year': (item?.fiscalYear ?? widget.activeFiscalYear)
                ?.toString(),
            'allocated_amount': item?.allocatedAmount.toStringAsFixed(0),
            'notes': item?.notes,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderDropdown<String>(
                name: 'program_id',
                decoration: const InputDecoration(labelText: 'البرنامج'),
                items: widget.programs
                    .map(
                      (program) => DropdownMenuItem<String>(
                        value: program.id,
                        child: Text(program.name),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
                onChanged: (value) {
                  setState(() {
                    _programId = value;
                  });
                  _formKey.currentState?.fields['budget_section_id']?.didChange(
                    null,
                  );
                },
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'budget_section_id',
                decoration: const InputDecoration(labelText: 'الباب'),
                items: availableSections
                    .where((section) => section.isPostable && section.isActive)
                    .map(
                      (section) => DropdownMenuItem<String>(
                        value: section.id,
                        child: Text('${section.fullCode} - ${section.name}'),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'funding_reference',
                decoration: const InputDecoration(labelText: 'مرجع التخصيص'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'fiscal_year',
                decoration: const InputDecoration(
                  labelText: 'السنة المالية',
                  helperText: 'تُملأ تلقائياً من السنة المالية الفعالة',
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.integer(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'allocated_amount',
                decoration: const InputDecoration(labelText: 'مبلغ التخصيص'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'notes',
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    Navigator.of(context).pop({
      'program_id': values['program_id']?.toString(),
      'budget_section_id': values['budget_section_id']?.toString(),
      'funding_reference': values['funding_reference']?.toString().trim(),
      'fiscal_year': int.parse(values['fiscal_year'].toString()),
      'allocated_amount': double.parse(values['allocated_amount'].toString()),
      'notes': values['notes']?.toString().trim(),
    });
  }
}

class _FundingsDataSource extends DataGridSource {
  _FundingsDataSource({
    required this.items,
    required this.formatter,
    required this.onEdit,
  });

  final List<FundingItem> items;
  final NumberFormat formatter;
  final Future<void> Function(FundingItem item) onEdit;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<FundingItem>(columnName: 'reference', value: item),
            DataGridCell<FundingItem>(columnName: 'program', value: item),
            DataGridCell<FundingItem>(columnName: 'section', value: item),
            DataGridCell<FundingItem>(columnName: 'year', value: item),
            DataGridCell<FundingItem>(
              columnName: 'initial_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(
              columnName: 'current_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(
              columnName: 'reserved_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(columnName: 'spent_amount', value: item),
            DataGridCell<FundingItem>(
              columnName: 'available_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as FundingItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.fundingReference),
        _GridCell(item.programName),
        _GridCell('${item.budgetSectionCode} - ${item.budgetSectionName}'),
        _GridCell(item.fiscalYear.toString()),
        _GridCell(formatter.format(item.allocatedAmount)),
        _GridCell(formatter.format(item.currentAllocatedAmount)),
        _GridCell(formatter.format(item.reservedAmount)),
        _GridCell(formatter.format(item.spentAmount)),
        _GridCell(formatter.format(item.availableAmount)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            onPressed: () => onEdit(item),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      ],
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(alignment: Alignment.centerRight, child: Text(text)),
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
      child: Align(alignment: Alignment.centerRight, child: Text(text)),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text('إجمالي السجلات: $total'),
          const Spacer(),
          OutlinedButton(onPressed: onPrevious, child: const Text('السابق')),
          const SizedBox(width: 8),
          Text('الصفحة $page من $totalPages'),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onNext, child: const Text('التالي')),
        ],
      ),
    );
  }
}
