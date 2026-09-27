import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../document_attachments/presentation/document_attachments_dialog.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../models/reservation_item.dart';
import '../controllers/reservations_controller.dart';
import '../../../../shared/widgets/date_filter_field.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/widgets/summary_title.dart';
import '../widgets/reservation_form_dialog.dart';
import '../widgets/reservation_details_dialog.dart';
import '../widgets/reservations_grid.dart';
import '../widgets/reservations_summary.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({
    super.key,
    this.initialProgramId,
    this.initialBudgetSectionId,
  });

  final String? initialProgramId;
  final String? initialBudgetSectionId;

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedProgramId;
  String? _selectedBudgetSectionId;
  String? _selectedStatus;
  String? _selectedExecutionStatus;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _appliedInitialFilters = false;
  final _filterDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _selectedProgramId = _emptyToNull(widget.initialProgramId);
    _selectedBudgetSectionId = _emptyToNull(widget.initialBudgetSectionId);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationsState = ref.watch(reservationsControllerProvider);
    final programsLookup = ref.watch(programLookupProvider);
    final budgetSectionsLookup = ref.watch(allBudgetSectionsLookupProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canAdd = currentUser?.canAddReservations ?? false;
    final canEdit = currentUser?.canEditReservations ?? false;
    final canApprove = currentUser?.canApproveReservations ?? false;
    final canCancel = currentUser?.canCancelReservations ?? false;
    final canSpend = currentUser?.canSpendReservations ?? false;
    final canDelete = currentUser?.canDeleteReservations ?? false;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(reservationsControllerProvider, (previous, next) {
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
            .read(reservationsControllerProvider.notifier)
            .refresh(showLoading: false),
      );
    });

    final availableSections =
        budgetSectionsLookup.asData?.value
            .where(
              (section) => (_selectedProgramId == null
                  ? true
                  : section.programId == _selectedProgramId),
            )
            .toList() ??
        const <BudgetSectionItem>[];
    final programDropdownValue =
        programsLookup.asData?.value.any(
              (program) => program.id == _selectedProgramId,
            ) ??
            false
        ? _selectedProgramId
        : null;
    final sectionDropdownValue =
        availableSections.any(
          (section) => section.id == _selectedBudgetSectionId,
        )
        ? _selectedBudgetSectionId
        : null;

    if (!_appliedInitialFilters &&
        (_selectedProgramId != null || _selectedBudgetSectionId != null)) {
      _appliedInitialFilters = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFilters();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
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
                        'الحجوزات',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة دورة الحجز من المسودة حتى الاعتماد مع متابعة الحالة وحجز المبالغ داخل السجل المالي.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      canAdd &&
                          programsLookup.hasValue &&
                          budgetSectionsLookup.hasValue
                      ? () => _openCreateDialog(
                          programsLookup.requireValue,
                          budgetSectionsLookup.requireValue,
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة حجز'),
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
                  width: 260,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالرقم أو العنوان',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => _scheduleApplyFilters(),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('كل الحالات')),
                      DropdownMenuItem(value: 'reserved', child: Text('محجوز')),
                      DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                      DropdownMenuItem(value: 'spent', child: Text('مصروف')),
                      DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                    ],
                    onChanged: (value) => _updateFilters(() {
                      _selectedStatus = value == '' ? null : value;
                    }),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: programsLookup.when(
                    data: (programs) => DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: programDropdownValue,
                      decoration: const InputDecoration(labelText: 'البرنامج'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('كل البرامج'),
                        ),
                        ...programs.map(
                          (program) => DropdownMenuItem<String>(
                            value: program.id,
                            child: Text(
                              program.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => _updateFilters(() {
                        _selectedProgramId = value == '' ? null : value;
                        _selectedBudgetSectionId = null;
                      }),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('تعذر تحميل البرامج'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: sectionDropdownValue,
                    decoration: const InputDecoration(labelText: 'الباب'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('كل الأبواب'),
                      ),
                      ...availableSections.map(
                        (section) => DropdownMenuItem<String>(
                          value: section.id,
                          child: Text(
                            '${section.fullCode} - ${section.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => _updateFilters(() {
                      _selectedBudgetSectionId = value == '' ? null : value;
                    }),
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
            SizedBox(
              height: 820,
              child: Card(
                child: AsyncValueView(
                  value: reservationsState,
                  onRetry: () => ref
                      .read(reservationsControllerProvider.notifier)
                      .refresh(),
                  data: (state) {
                    final summary = ReservationPageSummary.fromItems(
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
                                title: 'ملخص الحجوزات',
                                subtitle:
                                    'يعرض مبالغ الصفحة الحالية مع عدد النتائج حسب الفلاتر',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  ReservationSummaryCard(
                                    title: 'السجلات',
                                    value: state.result.pagination.total
                                        .toString(),
                                    // subtitle: 'إجمالي النتائج الحالية',
                                  ),
                                  ReservationSummaryCard(
                                    title: 'المحجوز',
                                    value: currency.format(summary.totalAmount),
                                    // subtitle: 'لا يشمل الحجوزات الملغية',
                                  ),
                                  ReservationSummaryCard(
                                    title: 'المصروف',
                                    value: currency.format(summary.totalSpent),
                                    // subtitle: 'حسب الصفحة الحالية',
                                  ),
                                  ReservationSummaryCard(
                                    title: 'المتبقي',
                                    value: currency.format(
                                      summary.totalRemaining,
                                    ),
                                    // subtitle: 'بعد احتساب الصرف',
                                  ),
                                  ReservationSummaryCard(
                                    title: 'الحالة',
                                    value:
                                        '${summary.reservedCount} محجوز / ${summary.approvedCount} معتمد',
                                    // subtitle: 'حسب السجلات غير الملغية',
                                  ),
                                  ReservationSummaryCard(
                                    title: 'الأرشيف',
                                    value: '${summary.cancelledCount} ملغي',
                                    // subtitle: 'لا يدخل بالمجاميع المالية',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        SizedBox(
                          height: 560,
                          child: SfDataGrid(
                            source: ReservationsDataSource(
                              items: state.result.items,
                              formatter: currency,
                              onDetails: (item) =>
                                  _showReservationDetails(item, currency),
                              onEdit: canEdit
                                  ? (item) async {
                                      if (!programsLookup.hasValue ||
                                          !budgetSectionsLookup.hasValue) {
                                        return;
                                      }
                                      await _openEditDialog(
                                        programsLookup.requireValue,
                                        budgetSectionsLookup.requireValue,
                                        item,
                                      );
                                    }
                                  : null,
                              onSubmit: canEdit ? _submitForReview : null,
                              onApprove: canApprove
                                  ? _approveReservation
                                  : null,
                              onCancel: canCancel ? _cancelReservation : null,
                              onSpend: canSpend
                                  ? _openExpenseForReservation
                                  : null,
                              onDelete: canDelete ? _deleteReservation : null,
                              onAttachments: (item) =>
                                  _openAttachments(item, canEdit || canAdd),
                            ),
                            columnWidthMode: ColumnWidthMode.none,
                            rowHeight: 62,
                            headerRowHeight: 58,
                            isScrollbarAlwaysShown: true,
                            showHorizontalScrollbar: true,
                            showVerticalScrollbar: true,
                            horizontalScrollPhysics:
                                const AlwaysScrollableScrollPhysics(),
                            verticalScrollPhysics:
                                const AlwaysScrollableScrollPhysics(),
                            columns: [
                              GridColumn(
                                columnName: 'number',
                                width: 120,
                                label: const ReservationGridHeader('رقم الحجز'),
                              ),
                              GridColumn(
                                columnName: 'title',
                                width: 210,
                                label: const ReservationGridHeader(
                                  'الجهة المحجوز لها',
                                ),
                              ),
                              GridColumn(
                                columnName: 'department',
                                width: 150,
                                label: const ReservationGridHeader('القسم'),
                              ),
                              GridColumn(
                                columnName: 'phone',
                                width: 130,
                                label: const ReservationGridHeader(
                                  'رقم الهاتف',
                                ),
                              ),
                              GridColumn(
                                columnName: 'section_code',
                                width: 130,
                                label: const ReservationGridHeader('رمز الباب'),
                              ),
                              GridColumn(
                                columnName: 'section_name',
                                width: 190,
                                label: const ReservationGridHeader('اسم الباب'),
                              ),
                              GridColumn(
                                columnName: 'budget',
                                width: 170,
                                label: const ReservationGridHeader('الميزانية'),
                              ),
                              GridColumn(
                                columnName: 'amount',
                                width: 120,
                                label: const ReservationGridHeader('المبلغ'),
                              ),
                              GridColumn(
                                columnName: 'date',
                                width: 130,
                                label: const ReservationGridHeader(
                                  'تاريخ الحجز',
                                ),
                              ),
                              GridColumn(
                                columnName: 'execution_note',
                                width: 220,
                                label: const ReservationGridHeader(
                                  'ملاحظة التنفيذ',
                                ),
                              ),
                              GridColumn(
                                columnName: 'status',
                                width: 180,
                                label: const ReservationGridHeader('الحالة'),
                              ),
                              GridColumn(
                                columnName: 'spent',
                                width: 120,
                                label: const ReservationGridHeader('المصروف'),
                              ),
                              GridColumn(
                                columnName: 'remaining',
                                width: 120,
                                label: const ReservationGridHeader('المتبقي'),
                              ),
                              GridColumn(
                                columnName: 'documents',
                                width: 130,
                                label: const ReservationGridHeader('المستندات'),
                              ),
                              GridColumn(
                                columnName: 'actions',
                                width: 170,
                                label: const ReservationGridHeader('إجراءات'),
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
                                    .read(
                                      reservationsControllerProvider.notifier,
                                    )
                                    .changePage(
                                      state.result.pagination.page - 1,
                                    )
                              : null,
                          onNext:
                              state.result.pagination.page <
                                  state.result.pagination.totalPages
                              ? () => ref
                                    .read(
                                      reservationsControllerProvider.notifier,
                                    )
                                    .changePage(
                                      state.result.pagination.page + 1,
                                    )
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
      ),
    );
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _openCreateDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          ReservationFormDialog(programs: programs, sections: sections),
    );

    if (payload == null || !mounted) return;
    try {
      await ref.read(reservationsControllerProvider.notifier).create(payload);
      if (!mounted) return;
      setState(() {
        _searchController.clear();
        _selectedProgramId = null;
        _selectedBudgetSectionId = null;
        _selectedStatus = null;
        _selectedExecutionStatus = null;
        _dateFrom = null;
        _dateTo = null;
      });
      await ref
          .read(reservationsControllerProvider.notifier)
          .applyFilters(
            search: '',
            status: '',
            programId: '',
            budgetSectionId: '',
            fundingId: '',
            executionStatus: '',
            dateFrom: '',
            dateTo: '',
          );
      _showMessage('تم إنشاء الحجز بنجاح وظهوره ضمن القائمة.');
    } on AppException catch (exception) {
      _showMessage(exception.message);
    } catch (exception) {
      _showMessage('تعذر إنشاء الحجز: $exception');
    }
  }

  Future<void> _openEditDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
    ReservationItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReservationFormDialog(
        programs: programs,
        sections: sections,
        initialValue: item,
      ),
    );

    if (payload == null || !mounted) return;
    try {
      await ref
          .read(reservationsControllerProvider.notifier)
          .updateReservation(item.id, payload);
      _showMessage('تم تحديث الحجز بنجاح.');
    } on AppException catch (exception) {
      _showMessage(exception.message);
    } catch (exception) {
      _showMessage('تعذر تحديث الحجز: $exception');
    }
  }

  Future<void> _submitForReview(ReservationItem item) async {
    final confirmed = await _confirmAction(
      title: 'إرسال للمراجعة',
      message:
          'سيتم نقل الحجز ${item.reservationNumber} إلى حالة قيد المراجعة.',
    );
    if (!confirmed) return;

    await ref
        .read(reservationsControllerProvider.notifier)
        .submitReservation(item.id);
    _showMessage('تم إرسال الحجز للمراجعة.');
  }

  Future<void> _approveReservation(ReservationItem item) async {
    final confirmed = await _confirmAction(
      title: 'اعتماد الحجز',
      message:
          'سيتم اعتماد الحجز ${item.reservationNumber} وحجز المبلغ داخل السجل المالي.',
    );
    if (!confirmed) return;

    await ref
        .read(reservationsControllerProvider.notifier)
        .approveReservation(item.id);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
    _showMessage('تم اعتماد الحجز وتحديث الرصيد المتاح.');
  }

  Future<void> _cancelReservation(ReservationItem item) async {
    final confirmed = await _confirmAction(
      title: 'إلغاء الحجز',
      message:
          'سيتم إلغاء الحجز ${item.reservationNumber}${item.workflowStatus == 'approved' ? ' مع تحرير المبلغ المحجوز.' : '.'}',
    );
    if (!confirmed) return;

    await ref
        .read(reservationsControllerProvider.notifier)
        .cancelReservation(item.id);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
    _showMessage('تم إلغاء الحجز بنجاح.');
  }

  Future<void> _deleteReservation(ReservationItem item) async {
    final confirmed = await _confirmAction(
      title: 'حذف الحجز',
      message:
          'سيتم إخفاء الحجز ${item.reservationNumber} من القوائم مع بقاء أثره في سجل الإجراءات. الحذف مسموح للحجز الملغي فقط.',
    );
    if (!confirmed) return;

    await ref
        .read(reservationsControllerProvider.notifier)
        .deleteReservation(item.id);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardSummaryByFiscalYearProvider);
    ref.invalidate(sectionSummaryProvider);
    _showMessage('تم حذف الحجز الملغي من القوائم.');
  }

  Future<void> _showReservationDetails(
    ReservationItem item,
    NumberFormat formatter,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          ReservationDetailsDialog(item: item, formatter: formatter),
    );
  }

  void _openExpenseForReservation(ReservationItem item) {
    // تعليق عربي: نمرر رقم الحجز لصفحة الصرف حتى يظهر محدداً وجاهزاً للمستخدم.
    context.go('/expenses?reservation_id=${item.id}&open_create=1');
  }

  Future<void> _openAttachments(ReservationItem item, bool canModify) async {
    await showDialog<void>(
      context: context,
      builder: (context) => DocumentAttachmentsDialog(
        entityType: 'reservation',
        entityId: item.id,
        title: 'مرفقات الحجز ${item.reservationNumber}',
        canModify: canModify,
      ),
    );
  }

  void _applyFilters() {
    ref
        .read(reservationsControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          status: _selectedStatus ?? '',
          programId: _selectedProgramId ?? '',
          budgetSectionId: _selectedBudgetSectionId ?? '',
          fundingId: '',
          executionStatus: _selectedExecutionStatus ?? '',
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
      _selectedProgramId = null;
      _selectedBudgetSectionId = null;
      _selectedStatus = null;
      _selectedExecutionStatus = null;
      _dateFrom = null;
      _dateTo = null;
    });
    ref
        .read(reservationsControllerProvider.notifier)
        .applyFilters(
          search: '',
          status: '',
          programId: '',
          budgetSectionId: '',
          fundingId: '',
          executionStatus: '',
          dateFrom: '',
          dateTo: '',
        );
  }

  void _scheduleApplyFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  String _formatDateParam(DateTime? value) =>
      value == null ? '' : _filterDateFormat.format(value);

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
