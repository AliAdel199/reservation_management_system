import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../reservations/models/reservation_item.dart';
import '../../../reservations/presentation/controllers/reservations_controller.dart';
import '../../models/expense_item.dart';
import '../controllers/expenses_controller.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({
    super.key,
    this.initialReservationId,
    this.openCreateOnLoad = false,
  });

  final String? initialReservationId;
  final bool openCreateOnLoad;

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _reservationId;
  bool _openedInitialDialog = false;

  @override
  void initState() {
    super.initState();
    _reservationId = widget.initialReservationId;
    if (_reservationId != null && _reservationId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFilters();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesControllerProvider);
    final reservations = ref.watch(spendableReservationsProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canModify = currentUser?.canModifyRecords ?? false;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(expensesControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    ref.listen(liveRefreshProvider, (previous, next) {
      if (!mounted || !next.hasValue) return;
      ref.invalidate(spendableReservationsProvider);
      unawaited(
        ref
            .read(expensesControllerProvider.notifier)
            .refresh(showLoading: false),
      );
    });

    if (widget.openCreateOnLoad &&
        !_openedInitialDialog &&
        reservations.hasValue) {
      _openedInitialDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCreateDialog(reservations.requireValue);
      });
    }

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
                      'الصرف',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تسجيل المصروفات المرتبطة بالحجوزات المعتمدة مع منع الصرف الزائد وتحديث السجل المالي.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: canModify && reservations.hasValue
                    ? () => _openCreateDialog(reservations.requireValue)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('إضافة صرف'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'بحث برقم الصرف أو الحجز',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _scheduleApplyFilters(),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 320,
                child: reservations.when(
                  data: (items) => DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: items.any((item) => item.id == _reservationId)
                        ? _reservationId
                        : null,
                    decoration: const InputDecoration(labelText: 'الحجز'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('كل الحجوزات'),
                      ),
                      ...items.map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            '${item.reservationNumber} - ${item.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => _updateFilters(() {
                      _reservationId = value == '' ? null : value;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('تعذر تحميل الحجوزات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: expensesState,
                onRetry: () =>
                    ref.read(expensesControllerProvider.notifier).refresh(),
                data: (state) {
                  return Column(
                    children: [
                      Expanded(
                        child: SfDataGrid(
                          source: _ExpensesDataSource(
                            items: state.result.items,
                            formatter: currency,
                            onCancel: canModify ? _cancelExpense : null,
                          ),
                          columnWidthMode: ColumnWidthMode.fill,
                          columns: [
                            GridColumn(
                              columnName: 'number',
                              label: const _GridHeader('رقم الصرف'),
                            ),
                            GridColumn(
                              columnName: 'reservation',
                              label: const _GridHeader('رقم الحجز'),
                            ),
                            GridColumn(
                              columnName: 'section',
                              label: const _GridHeader('الباب'),
                            ),
                            GridColumn(
                              columnName: 'amount',
                              label: const _GridHeader('المبلغ'),
                            ),
                            GridColumn(
                              columnName: 'date',
                              label: const _GridHeader('تاريخ الصرف'),
                            ),
                            GridColumn(
                              columnName: 'status',
                              label: const _GridHeader('الحالة'),
                            ),
                            GridColumn(
                              columnName: 'actions',
                              label: const _GridHeader('إجراءات'),
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
                                  .read(expensesControllerProvider.notifier)
                                  .changePage(state.result.pagination.page - 1)
                            : null,
                        onNext:
                            state.result.pagination.page <
                                state.result.pagination.totalPages
                            ? () => ref
                                  .read(expensesControllerProvider.notifier)
                                  .changePage(state.result.pagination.page + 1)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(List<ReservationItem> reservations) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ExpenseDialog(
        reservations: reservations,
        initialReservationId: _reservationId,
      ),
    );
    if (payload == null || !mounted) return;

    await ref.read(expensesControllerProvider.notifier).create(payload);
    ref.invalidate(reservationsControllerProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
    _showMessage('تم تسجيل الصرف وتحديث الحجز.');
  }

  Future<void> _cancelExpense(ExpenseItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _CancelExpenseDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    await ref
        .read(expensesControllerProvider.notifier)
        .cancel(item.id, reason.trim());
    ref.invalidate(reservationsControllerProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
    _showMessage('تم إلغاء الصرف وعكس الحركة في السجل المالي.');
  }

  void _applyFilters() {
    ref
        .read(expensesControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          reservationId: _reservationId ?? '',
        );
  }

  void _updateFilters(VoidCallback updateValues) {
    setState(updateValues);
    _applyFilters();
  }

  void _scheduleApplyFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.reservations, this.initialReservationId});

  final List<ReservationItem> reservations;
  final String? initialReservationId;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _reservationSearchController = TextEditingController();
  ReservationItem? _selectedReservation;
  String _reservationSearch = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialReservationId == null ||
        widget.initialReservationId!.isEmpty) {
      return;
    }

    for (final reservation in widget.reservations) {
      if (reservation.id == widget.initialReservationId) {
        _selectedReservation = reservation;
        _reservationSearchController.text = reservation.reservationNumber;
        _reservationSearch = reservation.reservationNumber;
        break;
      }
    }
  }

  @override
  void dispose() {
    _reservationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final visibleReservations = widget.reservations.where((item) {
      final query = _reservationSearch.trim().toLowerCase();
      if (query.isEmpty) return true;
      final haystack = [
        item.reservationNumber,
        item.title,
        item.programName,
        item.budgetSectionName,
        item.fundingReference,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('إضافة صرف'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'reservation_id': _selectedReservation?.id,
            'expense_date': DateTime.now(),
            'document_date': DateTime.now(),
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (widget.reservations.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9B44C)),
                  ),
                  child: const Text(
                    'لا توجد حجوزات قابلة للصرف. يجب أولاً إرسال الحجز للمراجعة ثم اعتماده من صفحة الحجوزات.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _reservationSearchController,
                enabled: widget.reservations.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'بحث عن الحجز',
                  hintText: 'رقم الحجز، العنوان، الباب، البرنامج، التخصيص',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _reservationSearch = value;
                    _selectedReservation = null;
                  });
                  _formKey.currentState?.fields['reservation_id']?.didChange(
                    null,
                  );
                },
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'reservation_id',
                decoration: const InputDecoration(labelText: 'الحجز'),
                enabled: visibleReservations.isNotEmpty,
                items: visibleReservations
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          '${item.reservationNumber} - ${item.title} - ${item.budgetSectionName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedReservation = null;
                    for (final item in widget.reservations) {
                      if (item.id == value) {
                        _selectedReservation = item;
                        break;
                      }
                    }
                  });
                },
              ),
              if (widget.reservations.isNotEmpty &&
                  visibleReservations.isEmpty) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('لا توجد حجوزات مطابقة للبحث.'),
                ),
              ],
              if (_selectedReservation != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9D6DF)),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text(
                        'مبلغ الحجز: ${currency.format(_selectedReservation!.reservedAmount)}',
                      ),
                      Text(
                        'المصروف سابقاً: ${currency.format(_selectedReservation!.spentAmount)}',
                      ),
                      Text(
                        'المتبقي: ${currency.format(_selectedReservation!.remainingAmount)}',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'expense_number',
                decoration: const InputDecoration(labelText: 'رقم الصرف'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(labelText: 'مبلغ الصرف'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                  (value) {
                    final amount = double.tryParse(value?.toString() ?? '');
                    final remaining = _selectedReservation?.remainingAmount;
                    if (amount != null &&
                        remaining != null &&
                        amount > remaining) {
                      return 'المبلغ أكبر من المتبقي بالحجز';
                    }
                    return null;
                  },
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'expense_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ الصرف'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'payment_method',
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('حوالة مصرفية'),
                  ),
                  DropdownMenuItem(value: 'check', child: Text('صك')),
                  DropdownMenuItem(
                    value: 'electronic',
                    child: Text('دفع إلكتروني'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'document_number',
                decoration: const InputDecoration(labelText: 'رقم المستند'),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'document_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ المستند'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'description',
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف'),
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
        FilledButton(
          onPressed: widget.reservations.isEmpty ? null : _submit,
          child: const Text('حفظ الصرف'),
        ),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    final rawDate = values['expense_date'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate.toString());
    final rawDocumentDate = values['document_date'];
    final parsedDocumentDate = rawDocumentDate is DateTime
        ? rawDocumentDate
        : DateTime.parse(rawDocumentDate.toString());

    Navigator.of(context).pop({
      'reservation_id': values['reservation_id']?.toString(),
      'expense_number': values['expense_number']?.toString().trim(),
      'amount': double.parse(values['amount'].toString()),
      'expense_date': DateFormat('yyyy-MM-dd').format(parsedDate),
      'payment_method': values['payment_method']?.toString().trim(),
      'document_number': values['document_number']?.toString().trim(),
      'document_date': DateFormat('yyyy-MM-dd').format(parsedDocumentDate),
      'description': values['description']?.toString().trim(),
    });
  }
}

class _CancelExpenseDialog extends StatefulWidget {
  const _CancelExpenseDialog();

  @override
  State<_CancelExpenseDialog> createState() => _CancelExpenseDialogState();
}

class _CancelExpenseDialogState extends State<_CancelExpenseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إلغاء الصرف'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تراجع'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('تأكيد الإلغاء'),
        ),
      ],
    );
  }
}

class _ExpensesDataSource extends DataGridSource {
  _ExpensesDataSource({
    required this.items,
    required this.formatter,
    this.onCancel,
  });

  final List<ExpenseItem> items;
  final NumberFormat formatter;
  final Future<void> Function(ExpenseItem item)? onCancel;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<ExpenseItem>(columnName: 'number', value: item),
            DataGridCell<ExpenseItem>(columnName: 'reservation', value: item),
            DataGridCell<ExpenseItem>(columnName: 'section', value: item),
            DataGridCell<ExpenseItem>(columnName: 'amount', value: item),
            DataGridCell<ExpenseItem>(columnName: 'date', value: item),
            DataGridCell<ExpenseItem>(columnName: 'status', value: item),
            DataGridCell<ExpenseItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as ExpenseItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.expenseNumber),
        _GridCell(item.reservationNumber),
        _GridCell(item.budgetSectionName),
        _GridCell(formatter.format(item.amount)),
        _GridCell(item.expenseDate),
        _GridCell(item.expenseStatus == 'cancelled' ? 'ملغي' : 'مصروف'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: item.expenseStatus == 'cancelled' || onCancel == null
                ? const Text('-')
                : IconButton(
                    onPressed: () => onCancel!(item),
                    icon: const Icon(Icons.undo_outlined),
                    tooltip: 'إلغاء الصرف',
                  ),
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
