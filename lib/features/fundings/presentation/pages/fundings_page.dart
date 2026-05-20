import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../models/funding_item.dart';
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
              FilledButton.icon(
                onPressed:
                    programsLookup.hasValue && budgetSectionsLookup.hasValue
                    ? () => _openCreateDialog(
                        programsLookup.requireValue,
                        budgetSectionsLookup.requireValue,
                      )
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('إضافة تخصيص'),
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
                            if (!programsLookup.hasValue ||
                                !budgetSectionsLookup.hasValue) {
                              return;
                            }
                            await _openEditDialog(
                              programsLookup.requireValue,
                              budgetSectionsLookup.requireValue,
                              item,
                            );
                          },
                        ),
                        columnWidthMode: ColumnWidthMode.fill,
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
                            columnName: 'amount',
                            label: _GridHeader('المبلغ'),
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
    List<BudgetSectionItem> sections,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _FundingDialog(programs: programs, sections: sections),
    );

    if (payload == null || !mounted) return;
    await ref.read(fundingsControllerProvider.notifier).create(payload);
    ref.invalidate(dashboardSummaryProvider);
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
    await ref
        .read(fundingsControllerProvider.notifier)
        .updateFunding(item.id, payload);
    ref.invalidate(dashboardSummaryProvider);
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
}

class _FundingDialog extends StatefulWidget {
  const _FundingDialog({
    required this.programs,
    required this.sections,
    this.initialValue,
  });

  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;
  final FundingItem? initialValue;

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
            'fiscal_year': item?.fiscalYear.toString(),
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
                    .map(
                      (section) => DropdownMenuItem<String>(
                        value: section.id,
                        child: Text('${section.code} - ${section.name}'),
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
                decoration: const InputDecoration(labelText: 'السنة المالية'),
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
            DataGridCell<FundingItem>(columnName: 'amount', value: item),
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
