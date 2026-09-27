import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../document_attachments/presentation/document_attachments_dialog.dart';
import '../../../institution/models/institution_settings_item.dart';
import '../../../institution/presentation/controllers/institution_controller.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../reservations/models/reservation_item.dart';
import '../../../reservations/presentation/controllers/reservations_controller.dart';
import '../../models/expense_item.dart';
import '../../services/expense_document_print_service.dart';
import '../controllers/expenses_controller.dart';
import '../../../../shared/widgets/date_filter_field.dart';
import '../../../../shared/widgets/grid_text_cells.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/widgets/summary_title.dart';
import '../widgets/expense_form_dialog.dart';
import '../widgets/cancel_expense_dialog.dart';
import '../widgets/expenses_grid.dart';
import '../widgets/expenses_summary.dart';

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
  final _documentPrintService = const ExpenseDocumentPrintService();
  Timer? _searchDebounce;
  String? _reservationId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _openedInitialDialog = false;
  final _filterDateFormat = DateFormat('yyyy-MM-dd');

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
    final institutionSettings = ref.watch(institutionControllerProvider);
    final reservations = ref.watch(spendableReservationsProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canAdd = currentUser?.canAddExpenses ?? false;
    final canCancel = currentUser?.canCancelExpenses ?? false;
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
                onPressed: canAdd && reservations.hasValue
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
              DateFilterField(
                label: 'من تاريخ',
                value: _dateFrom,
                formatter: _filterDateFormat,
                onChanged: (value) => _updateFilters(() {
                  _dateFrom = value;
                }),
              ),
              DateFilterField(
                label: 'إلى تاريخ',
                value: _dateTo,
                formatter: _filterDateFormat,
                onChanged: (value) => _updateFilters(() {
                  _dateTo = value;
                }),
              ),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('مسح الفلاتر'),
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
                  final summary = ExpensePageSummary.fromItems(
                    state.result.items,
                  );
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SummaryTitle(
                              title: 'ملخص الصرف',
                              subtitle:
                                  'يعرض مصروفات الصفحة الحالية حسب البحث والفترة المختارة',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ExpenseSummaryCard(
                                  title: 'السجلات ضمن الفلترة',
                                  value: state.result.pagination.total
                                      .toString(),
                                  subtitle: 'حسب البحث والفترة المختارة',
                                ),
                                ExpenseSummaryCard(
                                  title: 'الصرف الفعال',
                                  value: summary.activeCount.toString(),
                                  subtitle: 'سجلات غير ملغية',
                                ),
                                ExpenseSummaryCard(
                                  title: 'مصروف الصفحة الحالية',
                                  value: currency.format(summary.totalPaid),
                                  subtitle: 'لا يشمل الصرف الملغي',
                                ),
                                ExpenseSummaryCard(
                                  title: 'الصرف الملغي',
                                  value: currency.format(
                                    summary.cancelledAmount,
                                  ),
                                  subtitle:
                                      '${summary.cancelledCount} سجل ملغي',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: SfDataGrid(
                          source: ExpensesDataSource(
                            items: state.result.items,
                            formatter: currency,
                            onCancel: canCancel ? _cancelExpense : null,
                            onAttachments: (item) =>
                                _openAttachments(item, canAdd),
                            onPrintPaymentVoucher: (item) =>
                                _printPaymentVoucher(
                                  item,
                                  institutionSettings.asData?.value,
                                ),
                            onPrintJournalVoucher: (item) =>
                                _printJournalVoucher(
                                  item,
                                  institutionSettings.asData?.value,
                                ),
                          ),
                          columnWidthMode: ColumnWidthMode.fill,
                          columns: [
                            GridColumn(
                              columnName: 'number',
                              label: const GridHeaderText('رقم الصرف'),
                            ),
                            GridColumn(
                              columnName: 'reservation',
                              label: const GridHeaderText('رقم الحجز'),
                            ),
                            GridColumn(
                              columnName: 'section',
                              label: const GridHeaderText('الباب'),
                            ),
                            GridColumn(
                              columnName: 'amount',
                              label: const GridHeaderText('المبلغ'),
                            ),
                            GridColumn(
                              columnName: 'date',
                              label: const GridHeaderText('تاريخ الصرف'),
                            ),
                            GridColumn(
                              columnName: 'status',
                              label: const GridHeaderText('الحالة'),
                            ),
                            GridColumn(
                              columnName: 'documents',
                              label: const GridHeaderText('المستندات'),
                            ),
                            GridColumn(
                              columnName: 'actions',
                              label: const GridHeaderText('إجراءات'),
                            ),
                          ],
                        ),
                      ),
                      PaginationBar(
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
      builder: (context) => ExpenseFormDialog(
        reservations: reservations,
        initialReservationId: _reservationId,
      ),
    );
    if (payload == null || !mounted) return;

    try {
      await ref.read(expensesControllerProvider.notifier).create(payload);
      ref.invalidate(reservationsControllerProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardSummaryByFiscalYearProvider);
      ref.invalidate(sectionSummaryProvider);
      _showMessage('تم تسجيل الصرف وتحديث الحجز.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _cancelExpense(ExpenseItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const CancelExpenseDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    try {
      await ref
          .read(expensesControllerProvider.notifier)
          .cancel(item.id, reason.trim());
      ref.invalidate(reservationsControllerProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardSummaryByFiscalYearProvider);
      ref.invalidate(sectionSummaryProvider);
      _showMessage('تم إلغاء الصرف وعكس الحركة في السجل المالي.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openAttachments(ExpenseItem item, bool canModify) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DocumentAttachmentsDialog(
        entityType: 'expense',
        entityId: item.id,
        title: 'مرفقات الصرف ${item.expenseNumber}',
        canModify: canModify,
      ),
    );
  }

  Future<void> _printPaymentVoucher(
    ExpenseItem item,
    InstitutionSettingsItem? institutionSettings,
  ) async {
    try {
      await _documentPrintService.printPaymentVoucher(
        expense: item,
        institutionSettings: institutionSettings,
      );
      _showMessage('تم فتح سند الصرف للطباعة.');
    } catch (error) {
      _showMessage('تعذر إنشاء سند الصرف: $error');
    }
  }

  Future<void> _printJournalVoucher(
    ExpenseItem item,
    InstitutionSettingsItem? institutionSettings,
  ) async {
    try {
      await _documentPrintService.printJournalVoucher(
        expense: item,
        institutionSettings: institutionSettings,
      );
      _showMessage('تم فتح مستند القيد للطباعة.');
    } catch (error) {
      _showMessage('تعذر إنشاء مستند القيد: $error');
    }
  }

  void _applyFilters() {
    ref
        .read(expensesControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          reservationId: _reservationId ?? '',
          dateFrom: _formatDateParam(_dateFrom),
          dateTo: _formatDateParam(_dateTo),
        );
  }

  void _updateFilters(VoidCallback updateValues) {
    setState(updateValues);
    _applyFilters();
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _reservationId = null;
      _dateFrom = null;
      _dateTo = null;
    });
    ref
        .read(expensesControllerProvider.notifier)
        .applyFilters(search: '', reservationId: '', dateFrom: '', dateTo: '');
  }

  void _scheduleApplyFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  String _formatDateParam(DateTime? value) =>
      value == null ? '' : _filterDateFormat.format(value);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
