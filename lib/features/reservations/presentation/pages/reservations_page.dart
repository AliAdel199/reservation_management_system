import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../models/reservation_item.dart';
import '../controllers/reservations_controller.dart';

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
    final canModify = currentUser?.canModifyRecords ?? false;
    final canDelete = currentUser?.canDeleteRecords ?? false;
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
                    canModify &&
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
              _DateFilterField(
                label: 'من تاريخ',
                value: _dateFrom,
                formatter: _filterDateFormat,
                onChanged: (value) => _updateFilters(() {
                  _dateFrom = value;
                }),
              ),
              _DateFilterField(
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
                value: reservationsState,
                onRetry: () =>
                    ref.read(reservationsControllerProvider.notifier).refresh(),
                data: (state) {
                  final summary = _ReservationPageSummary.fromItems(
                    state.result.items,
                  );

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SummaryCard(
                              title: 'السجلات ضمن الفلترة',
                              value: state.result.pagination.total.toString(),
                              subtitle: 'إجمالي النتائج الحالية',
                            ),
                            _SummaryCard(
                              title: 'مبلغ الصفحة الحالية',
                              value: currency.format(summary.totalAmount),
                              subtitle: 'لا يشمل الحجوزات الملغية',
                            ),
                            _SummaryCard(
                              title: 'الحالة',
                              value:
                                  '${summary.reservedCount} محجوز / ${summary.approvedCount} معتمد',
                              subtitle: 'حسب السجلات غير الملغية',
                            ),
                            _SummaryCard(
                              title: 'الأرشيف',
                              value: '${summary.cancelledCount} ملغي',
                              subtitle: 'لا يدخل بالمجاميع المالية',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SfDataGrid(
                          source: _ReservationsDataSource(
                            items: state.result.items,
                            formatter: currency,
                            onDetails: (item) =>
                                _showReservationDetails(item, currency),
                            onEdit: canModify
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
                            onSubmit: canModify ? _submitForReview : null,
                            onApprove: canModify ? _approveReservation : null,
                            onCancel: canModify ? _cancelReservation : null,
                            onSpend: canModify
                                ? _openExpenseForReservation
                                : null,
                            onDelete: canDelete ? _deleteReservation : null,
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
                              label: const _GridHeader('رقم الحجز'),
                            ),
                            GridColumn(
                              columnName: 'title',
                              width: 210,
                              label: const _GridHeader('الجهة المحجوز لها'),
                            ),
                            GridColumn(
                              columnName: 'department',
                              width: 150,
                              label: const _GridHeader('القسم'),
                            ),
                            GridColumn(
                              columnName: 'phone',
                              width: 130,
                              label: const _GridHeader('رقم الهاتف'),
                            ),
                            GridColumn(
                              columnName: 'section_code',
                              width: 130,
                              label: const _GridHeader('رمز الباب'),
                            ),
                            GridColumn(
                              columnName: 'section_name',
                              width: 190,
                              label: const _GridHeader('اسم الباب'),
                            ),
                            GridColumn(
                              columnName: 'budget',
                              width: 170,
                              label: const _GridHeader('الميزانية'),
                            ),
                            GridColumn(
                              columnName: 'amount',
                              width: 120,
                              label: const _GridHeader('المبلغ'),
                            ),
                            GridColumn(
                              columnName: 'date',
                              width: 130,
                              label: const _GridHeader('تاريخ الحجز'),
                            ),
                            GridColumn(
                              columnName: 'execution_note',
                              width: 220,
                              label: const _GridHeader('ملاحظة التنفيذ'),
                            ),
                            GridColumn(
                              columnName: 'status',
                              width: 180,
                              label: const _GridHeader('الحالة'),
                            ),
                            GridColumn(
                              columnName: 'spent',
                              width: 120,
                              label: const _GridHeader('المصروف'),
                            ),
                            GridColumn(
                              columnName: 'remaining',
                              width: 120,
                              label: const _GridHeader('المتبقي'),
                            ),
                            GridColumn(
                              columnName: 'actions',
                              width: 170,
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
                                  .read(reservationsControllerProvider.notifier)
                                  .changePage(state.result.pagination.page - 1)
                            : null,
                        onNext:
                            state.result.pagination.page <
                                state.result.pagination.totalPages
                            ? () => ref
                                  .read(reservationsControllerProvider.notifier)
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
          _ReservationDialog(programs: programs, sections: sections),
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
      builder: (context) => _ReservationDialog(
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
          _ReservationDetailsDialog(item: item, formatter: formatter),
    );
  }

  void _openExpenseForReservation(ReservationItem item) {
    // تعليق عربي: نمرر رقم الحجز لصفحة الصرف حتى يظهر محدداً وجاهزاً للمستخدم.
    context.go('/expenses?reservation_id=${item.id}&open_create=1');
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

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: value == null ? '' : formatter.format(value!),
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.date_range_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: 'مسح التاريخ',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _ReservationDialog extends StatefulWidget {
  const _ReservationDialog({
    required this.programs,
    required this.sections,
    this.initialValue,
  });

  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;
  final ReservationItem? initialValue;

  @override
  State<_ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<_ReservationDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _programId;
  String? _budgetSectionId;

  String _normalizeAmount(String value) {
    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var normalized = value.trim();
    arabicDigits.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    // تعليق عربي: نسمح للمستخدم بكتابة الفواصل أو رمز العملة داخل مبلغ الحجز.
    return normalized.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  double? _parseAmount(dynamic value) {
    final normalized = _normalizeAmount(value?.toString() ?? '');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  @override
  void initState() {
    super.initState();
    _programId = widget.initialValue?.programId;
    _budgetSectionId = widget.initialValue?.budgetSectionId;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final availableSections = widget.sections
        .where(
          (section) =>
              section.isPostable &&
              (_programId == null ? true : section.programId == _programId),
        )
        .toList();
    final selectedSection = _budgetSectionId == null
        ? null
        : widget.sections.cast<BudgetSectionItem?>().firstWhere(
            (section) => section?.id == _budgetSectionId,
            orElse: () => null,
          );

    return AlertDialog(
      title: Text(item == null ? 'إضافة حجز' : 'تعديل حجز'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            initialValue: {
              'reservation_number': item?.reservationNumber,
              'program_id': item?.programId,
              'budget_section_id': item?.budgetSectionId,
              'beneficiary': item?.beneficiary,
              'requester_department': item?.requesterDepartment,
              'contact_phone': item?.contactPhone,
              'execution_note': item?.executionNote,
              'description': item?.description,
              'reserved_amount': item?.reservedAmount.toStringAsFixed(0),
              'reservation_date': item == null
                  ? null
                  : DateTime.tryParse(item.reservationDate),
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FormBuilderTextField(
                  name: 'reservation_number',
                  decoration: const InputDecoration(labelText: 'رقم الحجز'),
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
                      _budgetSectionId = null;
                    });
                    _formKey.currentState?.fields['budget_section_id']
                        ?.didChange(null);
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
                          child: Text('${section.fullCode} - ${section.name}'),
                        ),
                      )
                      .toList(),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _budgetSectionId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9D6DF)),
                  ),
                  child: Text(
                    selectedSection == null
                        ? 'اختر الباب حتى يظهر التخصيص السنوي المعتمد له.'
                        : 'التخصيص السنوي للباب المختار: ${currency.format(selectedSection.allocatedAmount)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF123B56),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'beneficiary',
                  decoration: const InputDecoration(
                    labelText: 'الجهة المحجوز لها',
                  ),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'requester_department',
                        decoration: const InputDecoration(labelText: 'القسم'),
                        validator: FormBuilderValidators.required(
                          errorText: 'الحقل مطلوب',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'contact_phone',
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                        ),
                        keyboardType: TextInputType.phone,
                        // validator: FormBuilderValidators.required(
                        //   errorText: 'الحقل مطلوب',
                        // ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'reserved_amount',
                  decoration: const InputDecoration(labelText: 'مبلغ الحجز'),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                    (value) {
                      final amount = _parseAmount(value);
                      if (amount == null) return 'أدخل مبلغاً صحيحاً';
                      if (amount <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
                      return null;
                    },
                  ]),
                ),
                const SizedBox(height: 12),
                FormBuilderDateTimePicker(
                  name: 'reservation_date',
                  inputType: InputType.date,
                  format: DateFormat('yyyy-MM-dd'),
                  decoration: const InputDecoration(labelText: 'تاريخ الحجز'),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'execution_note',
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة تنفيذ المحجوز',
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'description',
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
              ],
            ),
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
    final rawDate = values['reservation_date'];
    final amount = _parseAmount(values['reserved_amount']);
    if (amount == null || amount <= 0) return;
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate.toString());
    final beneficiary = values['beneficiary']?.toString().trim();

    Navigator.of(context).pop({
      'reservation_number': values['reservation_number']?.toString().trim(),
      'program_id': values['program_id']?.toString(),
      'budget_section_id': values['budget_section_id']?.toString(),
      // تعليق عربي: الجهة المحجوز لها هي العنوان العملي للحجز في سجل Excel الحكومي.
      'title': beneficiary,
      'beneficiary': beneficiary,
      'requester_department': values['requester_department']?.toString().trim(),
      'contact_phone': values['contact_phone']?.toString().trim(),
      'execution_note': values['execution_note']?.toString().trim(),
      'description': values['description']?.toString().trim(),
      'reserved_amount': amount,
      'reservation_date': DateFormat('yyyy-MM-dd').format(parsedDate),
    });
  }
}

class _ReservationDetailsDialog extends StatelessWidget {
  const _ReservationDetailsDialog({
    required this.item,
    required this.formatter,
  });

  final ReservationItem item;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final status = _StatusStyle.fromStatus(item.workflowStatus);

    return AlertDialog(
      title: Text('تفاصيل الحجز ${item.reservationNumber}'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DetailsPill(
                    label: 'الحالة',
                    value: status.label,
                    color: status.foreground,
                    background: status.background,
                  ),
                  _DetailsPill(
                    label: 'المبلغ',
                    value: formatter.format(item.reservedAmount),
                    color: const Color(0xFF123B56),
                    background: const Color(0xFFEFF6FA),
                  ),
                  _DetailsPill(
                    label: 'المتبقي',
                    value: formatter.format(item.remainingAmount),
                    color: const Color(0xFF0F7B49),
                    background: const Color(0xFFDEF7EC),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsRow(label: 'العنوان', value: item.title),
              _DetailsRow(
                label: 'الجهة المحجوز لها',
                value: _displayText(item.beneficiary),
              ),
              _DetailsRow(
                label: 'القسم',
                value: _displayText(item.requesterDepartment),
              ),
              _DetailsRow(
                label: 'رقم الهاتف',
                value: _displayText(item.contactPhone),
              ),
              _DetailsRow(label: 'البرنامج', value: item.programName),
              _DetailsRow(label: 'رمز الباب', value: item.budgetSectionCode),
              _DetailsRow(label: 'اسم الباب', value: item.budgetSectionName),
              _DetailsRow(
                label: 'مصدر التخصيص',
                value: 'التخصيص السنوي للباب المختار',
              ),
              _DetailsRow(label: 'تاريخ الحجز', value: item.reservationDate),
              _DetailsRow(
                label: 'المصروف',
                value: formatter.format(item.spentAmount),
              ),
              _DetailsRow(
                label: 'الرصيد المتاح عند القراءة',
                value: formatter.format(item.fundingAvailableBalance),
              ),
              if (item.approvedAt != null)
                _DetailsRow(label: 'تاريخ الاعتماد', value: item.approvedAt!),
              if (item.cancelledAt != null)
                _DetailsRow(label: 'تاريخ الإلغاء', value: item.cancelledAt!),
              if (item.closedAt != null)
                _DetailsRow(label: 'تاريخ الإغلاق', value: item.closedAt!),
              _DetailsRow(label: 'تاريخ الإنشاء', value: item.createdAt),
              if ((item.executionNote ?? '').trim().isNotEmpty)
                _DetailsRow(
                  label: 'ملاحظة تنفيذ المحجوز',
                  value: item.executionNote!,
                ),
              if ((item.description ?? '').trim().isNotEmpty)
                _DetailsRow(label: 'الوصف', value: item.description!),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _DetailsPill extends StatelessWidget {
  const _DetailsPill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ReservationsDataSource extends DataGridSource {
  _ReservationsDataSource({
    required this.items,
    required this.formatter,
    required this.onDetails,
    this.onEdit,
    this.onSubmit,
    this.onApprove,
    this.onCancel,
    this.onSpend,
    this.onDelete,
  });

  final List<ReservationItem> items;
  final NumberFormat formatter;
  final Future<void> Function(ReservationItem item) onDetails;
  final Future<void> Function(ReservationItem item)? onEdit;
  final Future<void> Function(ReservationItem item)? onSubmit;
  final Future<void> Function(ReservationItem item)? onApprove;
  final Future<void> Function(ReservationItem item)? onCancel;
  final void Function(ReservationItem item)? onSpend;
  final Future<void> Function(ReservationItem item)? onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<ReservationItem>(columnName: 'number', value: item),
            DataGridCell<ReservationItem>(columnName: 'title', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'department',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'phone', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'section_code',
              value: item,
            ),
            DataGridCell<ReservationItem>(
              columnName: 'section_name',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'budget', value: item),
            DataGridCell<ReservationItem>(columnName: 'amount', value: item),
            DataGridCell<ReservationItem>(columnName: 'date', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'execution_note',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'status', value: item),
            DataGridCell<ReservationItem>(columnName: 'spent', value: item),
            DataGridCell<ReservationItem>(columnName: 'remaining', value: item),
            DataGridCell<ReservationItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as ReservationItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.reservationNumber),
        _GridCell(_displayText(item.beneficiary)),
        _GridCell(_displayText(item.requesterDepartment)),
        _GridCell(_displayText(item.contactPhone)),
        _GridCell(item.budgetSectionCode),
        _GridCell(item.budgetSectionName),
        _GridCell(item.programName),
        _GridCell(formatter.format(item.reservedAmount)),
        _GridCell(_dateOnly(item.reservationDate)),
        _GridCell(_displayText(item.executionNote)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: _StatusBadge(status: item.workflowStatus),
          ),
        ),
        _GridCell(formatter.format(item.spentAmount)),
        _GridCell(formatter.format(item.remainingAmount)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _ReservationActionsMenu(
              item: item,
              onDetails: onDetails,
              onEdit: onEdit,
              onSubmit: onSubmit,
              onApprove: onApprove,
              onCancel: onCancel,
              onSpend: onSpend,
              onDelete: onDelete,
            ),
          ),
        ),
      ],
    );
  }
}

String _displayText(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? '-' : normalized;
}

String _dateOnly(String value) {
  return value.length >= 10 ? value.substring(0, 10) : value;
}

class _ReservationActionsMenu extends StatelessWidget {
  const _ReservationActionsMenu({
    required this.item,
    required this.onDetails,
    this.onEdit,
    this.onSubmit,
    this.onApprove,
    this.onCancel,
    this.onSpend,
    this.onDelete,
  });

  final ReservationItem item;
  final Future<void> Function(ReservationItem item) onDetails;
  final Future<void> Function(ReservationItem item)? onEdit;
  final Future<void> Function(ReservationItem item)? onSubmit;
  final Future<void> Function(ReservationItem item)? onApprove;
  final Future<void> Function(ReservationItem item)? onCancel;
  final void Function(ReservationItem item)? onSpend;
  final Future<void> Function(ReservationItem item)? onDelete;

  @override
  Widget build(BuildContext context) {
    final canSpend =
        item.remainingAmount > 0 && item.workflowStatus == 'approved';
    final actions = <PopupMenuEntry<_ReservationAction>>[
      const PopupMenuItem(
        value: _ReservationAction.details,
        child: _ActionLabel(icon: Icons.visibility_outlined, label: 'تفاصيل'),
      ),
      if (onEdit != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review'))
        const PopupMenuItem(
          value: _ReservationAction.edit,
          child: _ActionLabel(icon: Icons.edit_outlined, label: 'تعديل'),
        ),
      if (onApprove != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review'))
        const PopupMenuItem(
          value: _ReservationAction.approve,
          child: _ActionLabel(icon: Icons.verified_outlined, label: 'اعتماد'),
        ),
      if (onSpend != null && canSpend)
        const PopupMenuItem(
          value: _ReservationAction.spend,
          child: _ActionLabel(icon: Icons.payments_outlined, label: 'صرف'),
        ),
      if (onCancel != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review' ||
              item.workflowStatus == 'approved'))
        const PopupMenuItem(
          value: _ReservationAction.cancel,
          child: _ActionLabel(icon: Icons.cancel_outlined, label: 'إلغاء'),
        ),
      if (onDelete != null && item.workflowStatus == 'cancelled')
        const PopupMenuItem(
          value: _ReservationAction.delete,
          child: _ActionLabel(icon: Icons.delete_outline, label: 'حذف'),
        ),
    ];

    return PopupMenuButton<_ReservationAction>(
      tooltip: 'إجراءات الحجز',
      onSelected: (value) {
        switch (value) {
          case _ReservationAction.details:
            onDetails(item);
          case _ReservationAction.edit:
            onEdit?.call(item);
          case _ReservationAction.submit:
            onSubmit?.call(item);
          case _ReservationAction.approve:
            onApprove?.call(item);
          case _ReservationAction.spend:
            onSpend?.call(item);
          case _ReservationAction.cancel:
            onCancel?.call(item);
          case _ReservationAction.delete:
            onDelete?.call(item);
        }
      },
      itemBuilder: (_) => actions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFC9D6DF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 18),
            SizedBox(width: 6),
            Text('إجراءات'),
          ],
        ),
      ),
    );
  }
}

enum _ReservationAction {
  details,
  edit,
  submit,
  approve,
  spend,
  cancel,
  delete,
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}

class _ReservationPageSummary {
  const _ReservationPageSummary({
    required this.totalAmount,
    required this.reservedCount,
    required this.approvedCount,
    required this.cancelledCount,
  });

  final double totalAmount;
  final int reservedCount;
  final int approvedCount;
  final int cancelledCount;

  factory _ReservationPageSummary.fromItems(List<ReservationItem> items) {
    final activeItems = items
        .where((item) => item.workflowStatus != 'cancelled')
        .toList();

    return _ReservationPageSummary(
      totalAmount: activeItems.fold<double>(
        0,
        (sum, item) => sum + item.reservedAmount,
      ),
      reservedCount: activeItems
          .where(
            (item) =>
                item.workflowStatus == 'draft' ||
                item.workflowStatus == 'under_review',
          )
          .length,
      approvedCount: activeItems
          .where((item) => item.workflowStatus == 'approved')
          .length,
      cancelledCount: items
          .where((item) => item.workflowStatus == 'cancelled')
          .length,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF123B56),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _StatusStyle.fromStatus(status);

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: style.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  factory _StatusStyle.fromStatus(String status) {
    switch (status) {
      case 'draft':
      case 'under_review':
        return const _StatusStyle(
          label: 'محجوز',
          background: Color(0xFFE9EEF5),
          foreground: Color(0xFF35536B),
        );
      case 'approved':
        return const _StatusStyle(
          label: 'معتمد',
          background: Color(0xFFDEF7EC),
          foreground: Color(0xFF0F7B49),
        );
      case 'partially_spent':
      case 'completed':
      case 'fully_spent':
        return const _StatusStyle(
          label: 'مصروف',
          background: Color(0xFFE7F6E7),
          foreground: Color(0xFF256029),
        );
      case 'cancelled':
        return const _StatusStyle(
          label: 'ملغي',
          background: Color(0xFFFDE8E8),
          foreground: Color(0xFFB42318),
        );
      default:
        return const _StatusStyle(
          label: 'غير معروف',
          background: Color(0xFFE9EEF5),
          foreground: Color(0xFF35536B),
        );
    }
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
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
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: text,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
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
