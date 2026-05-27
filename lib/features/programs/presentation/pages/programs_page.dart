import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../models/program_item.dart';
import '../controllers/programs_controller.dart';

class ProgramsPage extends ConsumerStatefulWidget {
  const ProgramsPage({super.key});

  @override
  ConsumerState<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends ConsumerState<ProgramsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programsState = ref.watch(programsControllerProvider);
    final fiscalYearsState = ref.watch(fiscalYearsLookupProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canAdd = currentUser?.canAddPrograms ?? false;
    final canEdit = currentUser?.canEditPrograms ?? false;
    final canDelete = currentUser?.canDeletePrograms ?? false;
    final selectedFiscalYearId = programsState.asData?.value.fiscalYearId;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(programsControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

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
                      'البرامج',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة البرامج مع البحث والترقيم وتجهيز الربط مع الأبواب والتخصيصات.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: canAdd && fiscalYearsState.hasValue
                    ? () => _openCreateDialog(fiscalYearsState.requireValue)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('إضافة برنامج'),
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
                    labelText: 'بحث باسم البرنامج',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) => ref
                      .read(programsControllerProvider.notifier)
                      .search(value),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedFiscalYearId,
                  decoration: const InputDecoration(labelText: 'السنة المالية'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('السنة المفتوحة'),
                    ),
                    ...?fiscalYearsState.asData?.value.map(
                      (year) => DropdownMenuItem<String>(
                        value: year.id,
                        child: Text(year.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => ref
                      .read(programsControllerProvider.notifier)
                      .filterFiscalYear(value),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(programsControllerProvider.notifier)
                    .search(_searchController.text),
                child: const Text('بحث'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  ref.read(programsControllerProvider.notifier).resetFilters();
                },
                child: const Text('إعادة ضبط'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: programsState,
                onRetry: () =>
                    ref.read(programsControllerProvider.notifier).refresh(),
                data: (state) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: _ProgramsDataSource(
                          programs: state.result.items,
                          formatter: currency,
                          onEdit: canEdit
                              ? (item) async {
                                  if (!fiscalYearsState.hasValue) return;
                                  await _openEditDialog(
                                    fiscalYearsState.requireValue,
                                    item,
                                  );
                                }
                              : null,
                          onDelete: canDelete ? _deleteProgram : null,
                        ),
                        columnWidthMode: ColumnWidthMode.fill,
                        columns: [
                          GridColumn(
                            columnName: 'name',
                            label: _GridHeader('الاسم'),
                          ),
                          GridColumn(
                            columnName: 'year',
                            label: _GridHeader('السنة'),
                          ),
                          GridColumn(
                            columnName: 'status',
                            label: _GridHeader('الحالة'),
                          ),
                          GridColumn(
                            columnName: 'sections',
                            label: _GridHeader('الأبواب'),
                          ),
                          GridColumn(
                            columnName: 'total_allocations',
                            label: _GridHeader('مجموع التخصيصات'),
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
                                .read(programsControllerProvider.notifier)
                                .changePage(state.result.pagination.page - 1)
                          : null,
                      onNext:
                          state.result.pagination.page <
                              state.result.pagination.totalPages
                          ? () => ref
                                .read(programsControllerProvider.notifier)
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

  Future<void> _openCreateDialog(List<FiscalYearItem> fiscalYears) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProgramDialog(fiscalYears: fiscalYears),
    );

    if (payload == null || !mounted) {
      return;
    }

    await ref.read(programsControllerProvider.notifier).create(payload);
  }

  Future<void> _openEditDialog(
    List<FiscalYearItem> fiscalYears,
    ProgramItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _ProgramDialog(fiscalYears: fiscalYears, initialValue: item),
    );

    if (payload == null || !mounted) {
      return;
    }

    await ref
        .read(programsControllerProvider.notifier)
        .updateProgram(item.id, payload);
  }

  Future<void> _deleteProgram(ProgramItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البرنامج'),
        content: Text(
          'هل تريد حذف البرنامج "${item.name}"؟\n'
          'سيتم منع الحذف إذا كان مرتبطاً بأبواب أو حجوزات أو حركات مالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(programsControllerProvider.notifier).remove(item.id);
  }
}

class _ProgramDialog extends StatefulWidget {
  const _ProgramDialog({required this.fiscalYears, this.initialValue});

  final List<FiscalYearItem> fiscalYears;
  final ProgramItem? initialValue;

  @override
  State<_ProgramDialog> createState() => _ProgramDialogState();
}

class _ProgramDialogState extends State<_ProgramDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;

    return AlertDialog(
      title: Text(item == null ? 'إضافة برنامج' : 'تعديل برنامج'),
      content: SizedBox(
        width: 520,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'name': item?.name,
            'description': item?.description,
            'fiscal_year_id': item?.fiscalYearId,
            'is_active': item?.isActive ?? true,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'اسم البرنامج'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'fiscal_year_id',
                decoration: const InputDecoration(labelText: 'السنة المالية'),
                items: widget.fiscalYears
                    .map(
                      (year) => DropdownMenuItem<String>(
                        value: year.id,
                        child: Text(year.name),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'description',
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 12),
              FormBuilderSwitch(name: 'is_active', title: const Text('فعال')),
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
    if (formState == null || !formState.saveAndValidate()) {
      return;
    }

    final values = formState.value;
    Navigator.of(context).pop({
      'name': values['name']?.toString().trim(),
      'description': values['description']?.toString().trim(),
      'fiscal_year_id': values['fiscal_year_id']?.toString(),
      'is_active': values['is_active'] as bool? ?? true,
    });
  }
}

class _ProgramsDataSource extends DataGridSource {
  _ProgramsDataSource({
    required this.programs,
    required this.formatter,
    this.onEdit,
    this.onDelete,
  });

  final List<ProgramItem> programs;
  final NumberFormat formatter;
  final Future<void> Function(ProgramItem item)? onEdit;
  final Future<void> Function(ProgramItem item)? onDelete;

  @override
  List<DataGridRow> get rows => programs
      .map(
        (program) => DataGridRow(
          cells: [
            DataGridCell<ProgramItem>(columnName: 'name', value: program),
            DataGridCell<ProgramItem>(columnName: 'year', value: program),
            DataGridCell<ProgramItem>(columnName: 'status', value: program),
            DataGridCell<ProgramItem>(columnName: 'sections', value: program),
            DataGridCell<ProgramItem>(
              columnName: 'total_allocations',
              value: program,
            ),
            DataGridCell<ProgramItem>(columnName: 'actions', value: program),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as ProgramItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.name),
        _GridCell(item.fiscalYearName ?? item.fiscalYear.toString()),
        _GridCell(item.isActive ? 'فعال' : 'معطل'),
        _GridCell(item.budgetSectionsCount.toString()),
        _GridCell(formatter.format(item.totalAllocations)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (onEdit != null)
                IconButton(
                  onPressed: () => onEdit!(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: () => onDelete!(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (onEdit == null && onDelete == null) const Text('معاينة'),
            ],
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
