import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../models/fiscal_year_item.dart';
import '../controllers/fiscal_years_controller.dart';

class FiscalYearsPage extends ConsumerStatefulWidget {
  const FiscalYearsPage({super.key});

  @override
  ConsumerState<FiscalYearsPage> createState() => _FiscalYearsPageState();
}

class _FiscalYearsPageState extends ConsumerState<FiscalYearsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fiscalYearsState = ref.watch(fiscalYearsControllerProvider);

    ref.listen(fiscalYearsControllerProvider, (previous, next) {
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
                      'السنوات المالية',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة السنة المالية النشطة وربطها بالبرامج والتخصيصات والحركات.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة سنة'),
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
                    labelText: 'بحث باسم السنة أو رقمها',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _applySearch, child: const Text('بحث')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: fiscalYearsState,
                onRetry: () =>
                    ref.read(fiscalYearsControllerProvider.notifier).refresh(),
                data: (state) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: _FiscalYearsDataSource(
                          items: state.result.items,
                          onEdit: _openEditDialog,
                          onActivate: _activateFiscalYear,
                          onDelete: _deleteFiscalYear,
                        ),
                        columnWidthMode: ColumnWidthMode.fill,
                        columns: [
                          GridColumn(
                            columnName: 'year',
                            label: _GridHeader('السنة'),
                          ),
                          GridColumn(
                            columnName: 'name',
                            label: _GridHeader('الاسم'),
                          ),
                          GridColumn(
                            columnName: 'start',
                            label: _GridHeader('البداية'),
                          ),
                          GridColumn(
                            columnName: 'end',
                            label: _GridHeader('النهاية'),
                          ),
                          GridColumn(
                            columnName: 'status',
                            label: _GridHeader('الحالة'),
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
                                .read(fiscalYearsControllerProvider.notifier)
                                .changePage(state.result.pagination.page - 1)
                          : null,
                      onNext:
                          state.result.pagination.page <
                              state.result.pagination.totalPages
                          ? () => ref
                                .read(fiscalYearsControllerProvider.notifier)
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

  Future<void> _openCreateDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _FiscalYearDialog(),
    );
    if (payload == null || !mounted) return;
    await ref.read(fiscalYearsControllerProvider.notifier).create(payload);
  }

  Future<void> _openEditDialog(FiscalYearItem item) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FiscalYearDialog(initialValue: item),
    );
    if (payload == null || !mounted) return;
    await ref
        .read(fiscalYearsControllerProvider.notifier)
        .updateFiscalYear(item.id, payload);
  }

  Future<void> _activateFiscalYear(FiscalYearItem item) async {
    await ref.read(fiscalYearsControllerProvider.notifier).activate(item.id);
  }

  Future<void> _deleteFiscalYear(FiscalYearItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السنة المالية'),
        content: Text('هل تريد حذف "${item.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(fiscalYearsControllerProvider.notifier).remove(item.id);
  }

  void _applySearch() {
    ref
        .read(fiscalYearsControllerProvider.notifier)
        .search(_searchController.text);
  }
}

class _FiscalYearDialog extends StatefulWidget {
  const _FiscalYearDialog({this.initialValue});

  final FiscalYearItem? initialValue;

  @override
  State<_FiscalYearDialog> createState() => _FiscalYearDialogState();
}

class _FiscalYearDialogState extends State<_FiscalYearDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;

    return AlertDialog(
      title: Text(item == null ? 'إضافة سنة مالية' : 'تعديل سنة مالية'),
      content: SizedBox(
        width: 520,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'year': item?.year.toString(),
            'name': item?.name,
            'start_date': item == null
                ? null
                : DateTime.tryParse(item.startDate),
            'end_date': item == null ? null : DateTime.tryParse(item.endDate),
            'is_active': item?.isActive ?? false,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'year',
                decoration: const InputDecoration(labelText: 'السنة'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.integer(errorText: 'أدخل سنة صحيحة'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'اسم السنة'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'start_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ البداية'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'end_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ النهاية'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderSwitch(
                name: 'is_active',
                title: const Text('السنة النشطة'),
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
    final start = values['start_date'] as DateTime;
    final end = values['end_date'] as DateTime;

    Navigator.of(context).pop({
      'year': int.parse(values['year'].toString()),
      'name': values['name']?.toString().trim(),
      'start_date': DateFormat('yyyy-MM-dd').format(start),
      'end_date': DateFormat('yyyy-MM-dd').format(end),
      'is_active': values['is_active'] as bool? ?? false,
    });
  }
}

class _FiscalYearsDataSource extends DataGridSource {
  _FiscalYearsDataSource({
    required this.items,
    required this.onEdit,
    required this.onActivate,
    required this.onDelete,
  });

  final List<FiscalYearItem> items;
  final Future<void> Function(FiscalYearItem item) onEdit;
  final Future<void> Function(FiscalYearItem item) onActivate;
  final Future<void> Function(FiscalYearItem item) onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<FiscalYearItem>(columnName: 'year', value: item),
            DataGridCell<FiscalYearItem>(columnName: 'name', value: item),
            DataGridCell<FiscalYearItem>(columnName: 'start', value: item),
            DataGridCell<FiscalYearItem>(columnName: 'end', value: item),
            DataGridCell<FiscalYearItem>(columnName: 'status', value: item),
            DataGridCell<FiscalYearItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as FiscalYearItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.year.toString()),
        _GridCell(item.name),
        _GridCell(_shortDate(item.startDate)),
        _GridCell(_shortDate(item.endDate)),
        _GridCell(item.isActive ? 'نشطة' : 'غير نشطة'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onEdit(item),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل',
              ),
              IconButton(
                onPressed: item.isActive ? null : () => onActivate(item),
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'تفعيل',
              ),
              IconButton(
                onPressed: () => onDelete(item),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'حذف',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortDate(String value) => value.split(' ').first;
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
