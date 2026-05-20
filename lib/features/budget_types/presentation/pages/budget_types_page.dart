import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../models/budget_type_item.dart';
import '../controllers/budget_types_controller.dart';

class BudgetTypesPage extends ConsumerStatefulWidget {
  const BudgetTypesPage({super.key});

  @override
  ConsumerState<BudgetTypesPage> createState() => _BudgetTypesPageState();
}

class _BudgetTypesPageState extends ConsumerState<BudgetTypesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetTypesState = ref.watch(budgetTypesControllerProvider);

    ref.listen(budgetTypesControllerProvider, (previous, next) {
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
                      'أنواع الميزانيات',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تصنيف الأبواب والتمويلات حسب نوع الميزانية المعتمد.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة نوع'),
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
                    labelText: 'بحث بالرمز أو الاسم',
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
                value: budgetTypesState,
                onRetry: () =>
                    ref.read(budgetTypesControllerProvider.notifier).refresh(),
                data: (state) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: _BudgetTypesDataSource(
                          items: state.result.items,
                          onEdit: _openEditDialog,
                          onDelete: _deleteBudgetType,
                        ),
                        columnWidthMode: ColumnWidthMode.fill,
                        columns: [
                          GridColumn(
                            columnName: 'code',
                            label: _GridHeader('الرمز'),
                          ),
                          GridColumn(
                            columnName: 'name',
                            label: _GridHeader('الاسم'),
                          ),
                          GridColumn(
                            columnName: 'description',
                            label: _GridHeader('الوصف'),
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
                                .read(budgetTypesControllerProvider.notifier)
                                .changePage(state.result.pagination.page - 1)
                          : null,
                      onNext:
                          state.result.pagination.page <
                              state.result.pagination.totalPages
                          ? () => ref
                                .read(budgetTypesControllerProvider.notifier)
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
      builder: (context) => const _BudgetTypeDialog(),
    );
    if (payload == null || !mounted) return;
    await ref.read(budgetTypesControllerProvider.notifier).create(payload);
  }

  Future<void> _openEditDialog(BudgetTypeItem item) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _BudgetTypeDialog(initialValue: item),
    );
    if (payload == null || !mounted) return;
    await ref
        .read(budgetTypesControllerProvider.notifier)
        .updateBudgetType(item.id, payload);
  }

  Future<void> _deleteBudgetType(BudgetTypeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نوع الميزانية'),
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
    await ref.read(budgetTypesControllerProvider.notifier).remove(item.id);
  }

  void _applySearch() {
    ref
        .read(budgetTypesControllerProvider.notifier)
        .search(_searchController.text);
  }
}

class _BudgetTypeDialog extends StatefulWidget {
  const _BudgetTypeDialog({this.initialValue});

  final BudgetTypeItem? initialValue;

  @override
  State<_BudgetTypeDialog> createState() => _BudgetTypeDialogState();
}

class _BudgetTypeDialogState extends State<_BudgetTypeDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;

    return AlertDialog(
      title: Text(item == null ? 'إضافة نوع ميزانية' : 'تعديل نوع ميزانية'),
      content: SizedBox(
        width: 520,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'code': item?.code,
            'name': item?.name,
            'description': item?.description,
            'is_active': item?.isActive ?? true,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'code',
                decoration: const InputDecoration(labelText: 'الرمز'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'الاسم'),
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
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    Navigator.of(context).pop({
      'code': values['code']?.toString().trim(),
      'name': values['name']?.toString().trim(),
      'description': values['description']?.toString().trim(),
      'is_active': values['is_active'] as bool? ?? true,
    });
  }
}

class _BudgetTypesDataSource extends DataGridSource {
  _BudgetTypesDataSource({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BudgetTypeItem> items;
  final Future<void> Function(BudgetTypeItem item) onEdit;
  final Future<void> Function(BudgetTypeItem item) onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<BudgetTypeItem>(columnName: 'code', value: item),
            DataGridCell<BudgetTypeItem>(columnName: 'name', value: item),
            DataGridCell<BudgetTypeItem>(
              columnName: 'description',
              value: item,
            ),
            DataGridCell<BudgetTypeItem>(columnName: 'status', value: item),
            DataGridCell<BudgetTypeItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as BudgetTypeItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.code),
        _GridCell(item.name),
        _GridCell(item.description ?? '-'),
        _GridCell(item.isActive ? 'فعال' : 'معطل'),
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
