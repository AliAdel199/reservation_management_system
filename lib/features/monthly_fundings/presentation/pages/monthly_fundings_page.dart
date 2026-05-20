import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../models/monthly_funding_item.dart';
import '../controllers/monthly_fundings_controller.dart';

class MonthlyFundingsPage extends ConsumerStatefulWidget {
  const MonthlyFundingsPage({super.key});

  @override
  ConsumerState<MonthlyFundingsPage> createState() =>
      _MonthlyFundingsPageState();
}

class _MonthlyFundingsPageState extends ConsumerState<MonthlyFundingsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedFiscalYearId;
  String? _selectedProgramId;
  int? _selectedMonth;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthlyFundingsControllerProvider);
    final fiscalYears = ref.watch(fiscalYearsLookupProvider);
    final programs = ref.watch(programLookupProvider);
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(monthlyFundingsControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    ref.listen(liveRefreshProvider, (previous, next) {
      if (!mounted || !next.hasValue) return;
      unawaited(
        ref
            .read(monthlyFundingsControllerProvider.notifier)
            .refresh(showLoading: false),
      );
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardSummaryByFiscalYearProvider);
      ref.invalidate(sectionSummaryProvider);
    });

    final lookupsReady = fiscalYears.hasValue && programs.hasValue;

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
                      'التمويل الشهري',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تسجيل التمويلات الشهرية على مستوى البرنامج، ويستخرج النظام نوع الميزانية تلقائياً من أبوابه.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: lookupsReady
                    ? () => _openCreateDialog(
                        fiscalYears.requireValue,
                        programs.requireValue,
                      )
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('إضافة تمويل'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالملاحظات أو البرنامج',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _scheduleApplyFilters(),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 190,
                child: _lookupDropdown<FiscalYearItem>(
                  label: 'السنة المالية',
                  value: _selectedFiscalYearId,
                  items: fiscalYears.asData?.value ?? const [],
                  itemValue: (item) => item.id,
                  itemText: (item) => item.name,
                  onChanged: (value) => _updateFilters(() {
                    _selectedFiscalYearId = value;
                  }),
                ),
              ),
              SizedBox(
                width: 220,
                child: _lookupDropdown<ProgramItem>(
                  label: 'البرنامج',
                  value: _selectedProgramId,
                  items: programs.asData?.value ?? const [],
                  itemValue: (item) => item.id,
                  itemText: (item) => '${item.code} - ${item.name}',
                  onChanged: (value) => _updateFilters(() {
                    _selectedProgramId = value;
                  }),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الشهر'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('كل الأشهر'),
                    ),
                    ...List.generate(
                      12,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(
                          _monthName(index + 1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => _updateFilters(() {
                    _selectedMonth = value == 0 ? null : value;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: state,
                onRetry: () => ref
                    .read(monthlyFundingsControllerProvider.notifier)
                    .refresh(),
                data: (value) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: _MonthlyFundingsDataSource(
                          items: value.result.items,
                          formatter: currency,
                          onEdit: (item) async {
                            if (!lookupsReady) return;
                            await _openEditDialog(
                              fiscalYears.requireValue,
                              programs.requireValue,
                              item,
                            );
                          },
                          onDelete: _deleteMonthlyFunding,
                        ),
                        columnWidthMode: ColumnWidthMode.none,
                        columns: [
                          GridColumn(
                            columnName: 'year',
                            width: 110,
                            label: _GridHeader('السنة'),
                          ),
                          GridColumn(
                            columnName: 'program',
                            width: 220,
                            label: _GridHeader('البرنامج'),
                          ),
                          GridColumn(
                            columnName: 'month',
                            width: 150,
                            label: _GridHeader('الشهر'),
                          ),
                          GridColumn(
                            columnName: 'amount',
                            width: 150,
                            label: _GridHeader('المبلغ'),
                          ),
                          GridColumn(
                            columnName: 'reserved',
                            width: 150,
                            label: _GridHeader('المحجوز'),
                          ),
                          GridColumn(
                            columnName: 'spent',
                            width: 150,
                            label: _GridHeader('المصروف'),
                          ),
                          GridColumn(
                            columnName: 'remaining',
                            width: 150,
                            label: _GridHeader('المتبقي'),
                          ),
                          GridColumn(
                            columnName: 'actions',
                            width: 130,
                            label: _GridHeader('إجراءات'),
                          ),
                        ],
                      ),
                    ),
                    _PaginationBar(
                      page: value.result.pagination.page,
                      totalPages: value.result.pagination.totalPages,
                      total: value.result.pagination.total,
                      onPrevious: value.result.pagination.page > 1
                          ? () => ref
                                .read(
                                  monthlyFundingsControllerProvider.notifier,
                                )
                                .changePage(value.result.pagination.page - 1)
                          : null,
                      onNext:
                          value.result.pagination.page <
                              value.result.pagination.totalPages
                          ? () => ref
                                .read(
                                  monthlyFundingsControllerProvider.notifier,
                                )
                                .changePage(value.result.pagination.page + 1)
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

  Widget _lookupDropdown<T>({
    required String label,
    required String? value,
    required List<T> items,
    required String Function(T item) itemValue,
    required String Function(T item) itemText,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('الكل')),
        ...items.map(
          (item) => DropdownMenuItem<String>(
            value: itemValue(item),
            child: Text(itemText(item), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (newValue) => onChanged(newValue == '' ? null : newValue),
    );
  }

  Future<void> _openCreateDialog(
    List<FiscalYearItem> fiscalYears,
    List<ProgramItem> programs,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _MonthlyFundingDialog(fiscalYears: fiscalYears, programs: programs),
    );
    if (payload == null || !mounted) return;
    try {
      await ref
          .read(monthlyFundingsControllerProvider.notifier)
          .create(payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardSummaryByFiscalYearProvider);
      ref.invalidate(sectionSummaryProvider);
    } on AppException catch (exception) {
      _showMessage(exception.message);
    }
  }

  Future<void> _openEditDialog(
    List<FiscalYearItem> fiscalYears,
    List<ProgramItem> programs,
    MonthlyFundingItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MonthlyFundingDialog(
        fiscalYears: fiscalYears,
        programs: programs,
        initialValue: item,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      await ref
          .read(monthlyFundingsControllerProvider.notifier)
          .updateMonthlyFunding(item.id, payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardSummaryByFiscalYearProvider);
      ref.invalidate(sectionSummaryProvider);
    } on AppException catch (exception) {
      _showMessage(exception.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteMonthlyFunding(MonthlyFundingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التمويل الشهري'),
        content: Text('هل تريد حذف تمويل شهر ${_monthName(item.month)}؟'),
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
    await ref.read(monthlyFundingsControllerProvider.notifier).remove(item.id);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
  }

  void _updateFilters(VoidCallback updateValues) {
    setState(updateValues);
    _applyFilters();
  }

  void _scheduleApplyFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  void _applyFilters() {
    ref
        .read(monthlyFundingsControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          fiscalYearId: _selectedFiscalYearId,
          budgetTypeId: null,
          programId: _selectedProgramId,
          sectionId: null,
          month: _selectedMonth ?? 0,
        );
  }
}

class _MonthlyFundingDialog extends StatefulWidget {
  const _MonthlyFundingDialog({
    required this.fiscalYears,
    required this.programs,
    this.initialValue,
  });

  final List<FiscalYearItem> fiscalYears;
  final List<ProgramItem> programs;
  final MonthlyFundingItem? initialValue;

  @override
  State<_MonthlyFundingDialog> createState() => _MonthlyFundingDialogState();
}

class _MonthlyFundingDialogState extends State<_MonthlyFundingDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;

    return AlertDialog(
      title: Text(item == null ? 'إضافة تمويل شهري' : 'تعديل تمويل شهري'),
      content: SizedBox(
        width: 620,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'fiscal_year_id': item?.fiscalYearId,
            'program_id': item?.programId,
            'month': item?.month,
            'amount': item?.amount.toStringAsFixed(0),
            'funding_date': item == null
                ? DateTime.now()
                : DateTime.tryParse(item.fundingDate),
            'notes': item?.notes,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderDropdown<String>(
                name: 'fiscal_year_id',
                decoration: const InputDecoration(labelText: 'السنة المالية'),
                items: widget.fiscalYears
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'program_id',
                decoration: const InputDecoration(labelText: 'البرنامج'),
                items: widget.programs
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text('${item.code} - ${item.name}'),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<int>(
                name: 'month',
                decoration: const InputDecoration(labelText: 'الشهر'),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_monthName(index + 1)),
                  ),
                ),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(labelText: 'المبلغ'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'funding_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ التمويل'),
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
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    final fundingDate = values['funding_date'] as DateTime;

    Navigator.of(context).pop({
      'fiscal_year_id': values['fiscal_year_id']?.toString(),
      'program_id': values['program_id']?.toString(),
      'month': values['month'] as int,
      'amount': double.parse(values['amount'].toString()),
      'funding_date': DateFormat('yyyy-MM-dd').format(fundingDate),
      'notes': values['notes']?.toString().trim(),
    });
  }
}

class _MonthlyFundingsDataSource extends DataGridSource {
  _MonthlyFundingsDataSource({
    required this.items,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MonthlyFundingItem> items;
  final NumberFormat formatter;
  final Future<void> Function(MonthlyFundingItem item) onEdit;
  final Future<void> Function(MonthlyFundingItem item) onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<MonthlyFundingItem>(columnName: 'year', value: item),
            DataGridCell<MonthlyFundingItem>(
              columnName: 'program',
              value: item,
            ),
            DataGridCell<MonthlyFundingItem>(columnName: 'month', value: item),
            DataGridCell<MonthlyFundingItem>(columnName: 'amount', value: item),
            DataGridCell<MonthlyFundingItem>(
              columnName: 'reserved',
              value: item,
            ),
            DataGridCell<MonthlyFundingItem>(columnName: 'spent', value: item),
            DataGridCell<MonthlyFundingItem>(
              columnName: 'remaining',
              value: item,
            ),
            DataGridCell<MonthlyFundingItem>(
              columnName: 'actions',
              value: item,
            ),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as MonthlyFundingItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.fiscalYear.toString()),
        _GridCell(item.programName),
        _GridCell(_monthName(item.month)),
        _GridCell(formatter.format(item.amount)),
        _GridCell(formatter.format(item.reservedAmount)),
        _GridCell(formatter.format(item.spentAmount)),
        _GridCell(
          formatter.format(item.remainingAmount),
          color: item.remainingAmount <= 50000 ? Colors.orange.shade800 : null,
        ),
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

String _monthName(int month) {
  const names = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];
  if (month < 1 || month > 12) return month.toString();
  return names[month - 1];
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
  const _GridCell(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: color == null
              ? null
              : TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
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
