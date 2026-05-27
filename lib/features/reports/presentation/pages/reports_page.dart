import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../institution/models/institution_settings_item.dart';
import '../../../institution/presentation/controllers/institution_controller.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../models/section_summary_item.dart';
import '../../services/report_export_service.dart';
import '../controllers/reports_controller.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, this.initialActivityFilter});

  final String? initialActivityFilter;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _exportService = const ReportExportService();
  String? _fiscalYearId;
  String? _programId;
  String? _sectionId;
  int _selectedMonth = DateTime.now().month;
  _ReportGrouping _grouping = _ReportGrouping.bySection;
  _ReportSort _sortMode = _ReportSort.sectionCodeAsc;
  _ReportActivityFilter _activityFilter = _ReportActivityFilter.all;
  bool _hideZeroAllocation = false;
  final Set<_ReportColumn> _visibleColumns = {..._ReportColumn.values};
  SectionSummaryFilters _filters = const SectionSummaryFilters();

  @override
  void initState() {
    super.initState();
    if (widget.initialActivityFilter == 'no_movement') {
      _activityFilter = _ReportActivityFilter.noMovement;
    }
    _filters = _buildCurrentFilters();
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(sectionSummaryProvider(_filters));
    final fiscalYears = ref.watch(fiscalYearsLookupProvider);
    final programs = ref.watch(programLookupProvider);
    final sections = ref.watch(allBudgetSectionsLookupProvider);
    final institutionSettings = ref.watch(institutionControllerProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canExportReports = currentUser?.canExportReports ?? false;
    final canPrintReports = currentUser?.canPrintReports ?? false;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(liveRefreshProvider, (previous, next) {
      if (!mounted || !next.hasValue) return;
      ref.invalidate(sectionSummaryProvider(_filters));
    });

    final availableSections =
        sections.asData?.value.where((section) {
          return (_fiscalYearId == null ||
                  section.fiscalYearId == _fiscalYearId) &&
              (_programId == null || section.programId == _programId);
        }).toList() ??
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
                      'التقارير',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تقرير ملخص الباب مع فرز حسب السنة أو البرنامج أو الباب والشهر.',
                    ),
                  ],
                ),
              ),
              reportState.maybeWhen(
                data: (items) {
                  final displayItems = _displayItems(items);
                  final visibleColumns = _orderedVisibleColumns();
                  if (!canPrintReports && !canExportReports) {
                    return const SizedBox.shrink();
                  }
                  return Wrap(
                    spacing: 8,
                    children: [
                      if (canPrintReports)
                        OutlinedButton.icon(
                          onPressed: displayItems.isEmpty
                              ? null
                              : () => _exportHtml(
                                  displayItems,
                                  visibleColumns: visibleColumns,
                                  institutionSettings:
                                      institutionSettings.asData?.value,
                                  openAfterExport: true,
                                ),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('طباعة'),
                        ),
                      if (canExportReports) ...[
                        OutlinedButton.icon(
                          onPressed: displayItems.isEmpty
                              ? null
                              : () => _exportHtml(
                                  displayItems,
                                  visibleColumns: visibleColumns,
                                  institutionSettings:
                                      institutionSettings.asData?.value,
                                  openAfterExport: false,
                                ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('تقرير HTML'),
                        ),
                        FilledButton.icon(
                          onPressed: displayItems.isEmpty
                              ? null
                              : () => _exportXlsx(
                                  displayItems,
                                  visibleColumns: visibleColumns,
                                  institutionSettings:
                                      institutionSettings.asData?.value,
                                ),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Excel'),
                        ),
                      ],
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: fiscalYears.when(
                      data: (items) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _fiscalYearId ?? '',
                        decoration: const InputDecoration(
                          labelText: 'السنة المالية',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('السنة المفتوحة'),
                          ),
                          ...items.map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => _updateFilters(() {
                          _fiscalYearId = _emptyToNull(value);
                          _sectionId = null;
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('تعذر تحميل السنوات'),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: programs.when(
                      data: (items) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _programId ?? '',
                        decoration: const InputDecoration(
                          labelText: 'البرنامج',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('كل البرامج'),
                          ),
                          ...items.map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text('${item.code} - ${item.name}'),
                            ),
                          ),
                        ],
                        onChanged: (value) => _updateFilters(() {
                          _programId = _emptyToNull(value);
                          _sectionId = null;
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('تعذر تحميل البرامج'),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _sectionId ?? '',
                      decoration: const InputDecoration(labelText: 'الباب'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('كل الأبواب'),
                        ),
                        ...availableSections.map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text('${item.code} - ${item.name}'),
                          ),
                        ),
                      ],
                      onChanged: (value) => _updateFilters(() {
                        _sectionId = _emptyToNull(value);
                      }),
                    ),
                  ),
                  _MonthFilterDropdown(
                    value: _selectedMonth,
                    onChanged: (value) => _updateFilters(() {
                      _selectedMonth = value;
                    }),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<_ReportGrouping>(
                      isExpanded: true,
                      initialValue: _grouping,
                      decoration: const InputDecoration(
                        labelText: 'طريقة العرض',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ReportGrouping.bySection,
                          child: Text('حسب الباب'),
                        ),
                        DropdownMenuItem(
                          value: _ReportGrouping.byProgram,
                          child: Text('حسب البرنامج'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _grouping = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<_ReportSort>(
                      isExpanded: true,
                      initialValue: _sortMode,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب الجدول',
                      ),
                      items: _ReportSort.values
                          .map(
                            (item) => DropdownMenuItem<_ReportSort>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sortMode = value);
                      },
                    ),
                  ),
                  FilterChip(
                    selected: _hideZeroAllocation,
                    avatar: const Icon(Icons.visibility_off_outlined, size: 18),
                    label: const Text('إخفاء تخصيص 0'),
                    onSelected: (value) {
                      setState(() => _hideZeroAllocation = value);
                    },
                  ),
                  FilterChip(
                    selected:
                        _activityFilter == _ReportActivityFilter.noMovement,
                    avatar: const Icon(Icons.hourglass_empty_rounded, size: 18),
                    label: const Text('أبواب بلا حركة'),
                    onSelected: (value) {
                      setState(() {
                        _activityFilter = value
                            ? _ReportActivityFilter.noMovement
                            : _ReportActivityFilter.all;
                      });
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: _openColumnsDialog,
                    icon: const Icon(Icons.view_column_outlined),
                    label: Text('الأعمدة (${_visibleColumns.length})'),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('مسح الفرز'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: reportState,
                onRetry: () => ref.invalidate(sectionSummaryProvider(_filters)),
                data: (items) {
                  final displayItems = _displayItems(items);
                  final monthName = _monthName(_selectedMonth);
                  final visibleColumns = _orderedVisibleColumns();

                  return Column(
                    children: [
                      _ReportSummary(
                        items: displayItems,
                        formatter: currency,
                        selectedMonth: _selectedMonth,
                      ),
                      const _HorizontalScrollHint(),
                      Expanded(
                        child: SfDataGrid(
                          source: _SectionSummaryDataSource(
                            items: displayItems,
                            formatter: currency,
                            selectedMonth: _selectedMonth,
                            grouping: _grouping,
                            columns: visibleColumns,
                          ),
                          // تعليق عربي: نستخدم أعمدة بعرض ثابت حتى لا تنضغط
                          // بيانات التقارير، ويظهر السكرول الأفقي عند الحاجة.
                          columnWidthMode: ColumnWidthMode.none,
                          headerRowHeight: 72,
                          rowHeight: 56,
                          isScrollbarAlwaysShown: true,
                          showHorizontalScrollbar: true,
                          showVerticalScrollbar: true,
                          horizontalScrollPhysics:
                              const AlwaysScrollableScrollPhysics(),
                          verticalScrollPhysics:
                              const AlwaysScrollableScrollPhysics(),
                          columns: _buildGridColumns(visibleColumns, monthName),
                        ),
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

  void _updateFilters(VoidCallback updateValues) {
    setState(() {
      updateValues();
      _filters = _buildCurrentFilters();
    });
  }

  SectionSummaryFilters _buildCurrentFilters() {
    final fiscalYear = _selectedFiscalYear();
    final year = fiscalYear?.year ?? DateTime.now().year;
    final dateTo = DateTime(year, _selectedMonth + 1, 0);

    return SectionSummaryFilters(
      fiscalYearId: _fiscalYearId,
      budgetTypeId: null,
      programId: _programId,
      sectionId: _sectionId,
      // تعليق عربي: اختيار الشهر يعني احتساب الحركات من بداية السنة
      // ولغاية نهاية الشهر المختار، حتى يطابق متابعة Excel.
      dateTo: _formatDate(dateTo),
    );
  }

  void _clearFilters() {
    setState(() {
      _fiscalYearId = null;
      _programId = null;
      _sectionId = null;
      _selectedMonth = DateTime.now().month;
      _grouping = _ReportGrouping.bySection;
      _sortMode = _ReportSort.sectionCodeAsc;
      _activityFilter = _ReportActivityFilter.all;
      _hideZeroAllocation = false;
      _visibleColumns
        ..clear()
        ..addAll(_ReportColumn.values);
      _filters = _buildCurrentFilters();
    });
  }

  List<SectionSummaryItem> _displayItems(List<SectionSummaryItem> items) {
    final result = _grouping == _ReportGrouping.bySection
        ? [...items]
        : _groupByProgram(items);

    final byAllocation = _hideZeroAllocation
        ? result.where((item) => item.allocatedAmount != 0).toList()
        : result;
    final filtered = _activityFilter == _ReportActivityFilter.noMovement
        ? byAllocation
              .where(
                (item) =>
                    item.allocatedAmount > 0 &&
                    item.totalReserved == 0 &&
                    item.totalSpent == 0,
              )
              .toList()
        : byAllocation;

    filtered.sort((a, b) => _sortMode.compare(a, b, _selectedMonth));
    return filtered;
  }

  List<SectionSummaryItem> _groupByProgram(List<SectionSummaryItem> items) {
    final grouped = <String, List<SectionSummaryItem>>{};
    for (final item in items) {
      final key = '${item.programCode}|${item.programName}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    double sum(
      List<SectionSummaryItem> rows,
      double Function(SectionSummaryItem item) selector,
    ) {
      return rows.fold<double>(0, (total, item) => total + selector(item));
    }

    return grouped.entries.map((entry) {
      final rows = entry.value;
      final first = rows.first;
      final allocated = sum(rows, (item) => item.allocatedAmount);
      final reserved = sum(rows, (item) => item.totalReserved);
      final spent = sum(rows, (item) => item.totalSpent);
      final reservationRate = allocated > 0 ? (reserved / allocated) * 100 : 0;
      final spendingRate = allocated > 0 ? (spent / allocated) * 100 : 0;

      return SectionSummaryItem(
        sectionCode: first.programCode,
        sectionName: 'مجموع البرنامج',
        programCode: first.programCode,
        programName: first.programName,
        fiscalYearName: first.fiscalYearName,
        budgetTypeName: first.budgetTypeName,
        allocatedAmount: allocated,
        totalFunding: sum(rows, (item) => item.totalFunding),
        totalReserved: reserved,
        totalSpent: spent,
        remainingAllocation: sum(rows, (item) => item.remainingAllocation),
        remainingBySpent: sum(rows, (item) => item.effectiveRemainingBySpent()),
        monthlyQuota: sum(rows, (item) => item.effectiveMonthlyQuota()),
        allowedMonths: _selectedMonth,
        periodAllowedAmount: sum(
          rows,
          (item) => item.effectivePeriodAllowed(_selectedMonth),
        ),
        periodDisposableAmount: sum(
          rows,
          (item) => item.effectivePeriodDisposable(_selectedMonth),
        ),
        remainingFunding: sum(rows, (item) => item.remainingFunding),
        disposableAmount: sum(rows, (item) => item.disposableAmount),
        reservationRate: reservationRate.toDouble(),
        spendingRate: spendingRate.toDouble(),
      );
    }).toList();
  }

  Future<void> _exportHtml(
    List<SectionSummaryItem> items, {
    required List<_ReportColumn> visibleColumns,
    required InstitutionSettingsItem? institutionSettings,
    required bool openAfterExport,
  }) async {
    final path = await _exportService.exportSectionSummaryHtml(
      items: items,
      filters: _activeFilterLabels(),
      selectedMonth: _selectedMonth,
      visibleColumns: visibleColumns.map((column) => column.key).toSet(),
      institutionSettings: institutionSettings,
      openAfterExport: openAfterExport,
    );
    _showMessage(
      openAfterExport ? 'تم فتح التقرير للطباعة.' : 'تم حفظ التقرير: $path',
    );
  }

  Future<void> _exportXlsx(
    List<SectionSummaryItem> items, {
    required List<_ReportColumn> visibleColumns,
    required InstitutionSettingsItem? institutionSettings,
  }) async {
    final path = await _exportService.exportSectionSummaryXlsx(
      items: items,
      filters: _activeFilterLabels(),
      selectedMonth: _selectedMonth,
      visibleColumns: visibleColumns.map((column) => column.key).toSet(),
      institutionSettings: institutionSettings,
    );
    _showMessage('تم تصدير ملف Excel: $path');
  }

  Map<String, String> _activeFilterLabels() {
    final fiscalYears = ref.read(fiscalYearsLookupProvider).asData?.value ?? [];
    final programs = ref.read(programLookupProvider).asData?.value ?? [];
    final sections =
        ref.read(allBudgetSectionsLookupProvider).asData?.value ?? [];

    String findFiscalYear() => _filters.fiscalYearId == null
        ? fiscalYears
                  .where((item) => item.isActive)
                  .map((item) => item.name)
                  .firstOrNull ??
              'السنة المفتوحة'
        : fiscalYears
                  .where((item) => item.id == _filters.fiscalYearId)
                  .map((item) => item.name)
                  .firstOrNull ??
              '';
    String findProgram() =>
        programs
            .where((item) => item.id == _filters.programId)
            .map((item) => item.name)
            .firstOrNull ??
        '';
    String findSection() =>
        sections
            .where((item) => item.id == _filters.sectionId)
            .map((item) => '${item.code} - ${item.name}')
            .firstOrNull ??
        '';

    return {
      'السنة المالية': findFiscalYear(),
      'البرنامج': findProgram(),
      'الباب': findSection(),
      'الشهر': _monthName(_selectedMonth),
      'طريقة العرض': _grouping.label,
      'الترتيب': _sortMode.label,
      'إخفاء تخصيص 0': _hideZeroAllocation ? 'نعم' : '',
      'الحركة': _activityFilter == _ReportActivityFilter.noMovement
          ? 'أبواب بلا حركة'
          : '',
    };
  }

  List<_ReportColumn> _orderedVisibleColumns() {
    return _ReportColumn.values
        .where((column) => _visibleColumns.contains(column))
        .toList();
  }

  List<GridColumn> _buildGridColumns(
    List<_ReportColumn> columns,
    String monthName,
  ) {
    return columns
        .map(
          (column) => GridColumn(
            columnName: column.key,
            width: column.width,
            label: _GridHeader(
              column.label(monthName: monthName, grouping: _grouping),
            ),
          ),
        )
        .toList();
  }

  Future<void> _openColumnsDialog() async {
    final selected = {..._visibleColumns};
    final result = await showDialog<Set<_ReportColumn>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('الأعمدة الظاهرة'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _ReportColumn.values.map((column) {
                      final checked = selected.contains(column);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(
                          column.label(
                            monthName: _monthName(_selectedMonth),
                            grouping: _grouping,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          if (value == null) return;
                          if (!value && selected.length == 1) {
                            _showMessage('يجب إبقاء عمود واحد على الأقل.');
                            return;
                          }
                          setDialogState(() {
                            if (value) {
                              selected.add(column);
                            } else {
                              selected.remove(column);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selected
                        ..clear()
                        ..addAll(_ReportColumn.values);
                    });
                  },
                  child: const Text('إظهار الكل'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('تطبيق'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;
    setState(() {
      _visibleColumns
        ..clear()
        ..addAll(result);
    });
  }

  FiscalYearItem? _selectedFiscalYear() {
    final fiscalYears = ref.read(fiscalYearsLookupProvider).asData?.value ?? [];
    if (_fiscalYearId == null) {
      return fiscalYears.where((item) => item.isActive).firstOrNull;
    }
    return fiscalYears.where((item) => item.id == _fiscalYearId).firstOrNull;
  }

  String? _emptyToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  String? _formatDate(DateTime? value) =>
      value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  static String _monthName(int month) => _arabicMonths[month - 1];

  static const List<String> _arabicMonths = [
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ReportGrouping {
  bySection('حسب الباب'),
  byProgram('حسب البرنامج');

  const _ReportGrouping(this.label);

  final String label;
}

enum _ReportActivityFilter { all, noMovement }

enum _ReportSort {
  sectionCodeAsc('رمز الباب تصاعدي'),
  allocationDesc('التخصيص الأعلى أولاً'),
  reservedDesc('المحجوز الأعلى أولاً'),
  spentDesc('المصروف الأعلى أولاً'),
  disposableAsc('الأقل قابل للصرف أولاً'),
  programNameAsc('اسم البرنامج تصاعدي');

  const _ReportSort(this.label);

  final String label;

  int compare(SectionSummaryItem a, SectionSummaryItem b, int selectedMonth) {
    switch (this) {
      case _ReportSort.sectionCodeAsc:
        return a.sectionCode.compareTo(b.sectionCode);
      case _ReportSort.allocationDesc:
        return b.allocatedAmount.compareTo(a.allocatedAmount);
      case _ReportSort.reservedDesc:
        return b.totalReserved.compareTo(a.totalReserved);
      case _ReportSort.spentDesc:
        return b.totalSpent.compareTo(a.totalSpent);
      case _ReportSort.disposableAsc:
        return a
            .effectivePeriodDisposable(selectedMonth)
            .compareTo(b.effectivePeriodDisposable(selectedMonth));
      case _ReportSort.programNameAsc:
        return a.programName.compareTo(b.programName);
    }
  }
}

enum _ReportColumn {
  program('program', 230),
  section('section', 300),
  allocation('allocation', 170),
  reserved('reserved', 190),
  unreserved('unreserved', 230),
  spent('spent', 160),
  remainingBySpent('remainingBySpent', 230),
  monthlyQuota('monthlyQuota', 180),
  periodAllowed('periodAllowed', 190),
  periodDisposable('periodDisposable', 190),
  rates('rates', 240);

  const _ReportColumn(this.key, this.width);

  final String key;
  final double width;

  String label({required String monthName, required _ReportGrouping grouping}) {
    switch (this) {
      case _ReportColumn.program:
        return 'البرنامج';
      case _ReportColumn.section:
        return grouping == _ReportGrouping.byProgram ? 'النطاق' : 'الباب';
      case _ReportColumn.allocation:
        return 'التخصيص';
      case _ReportColumn.reserved:
        return 'المحجوز من التخصيصات';
      case _ReportColumn.unreserved:
        return 'المتبقي من التخصيصات غير محجوز';
      case _ReportColumn.spent:
        return 'المصروف الفعلي';
      case _ReportColumn.remainingBySpent:
        return 'المتبقي من التخصيصات حسب المصروف';
      case _ReportColumn.monthlyQuota:
        return 'نسبة الحجز 1/12';
      case _ReportColumn.periodAllowed:
        return 'الحجز لغاية $monthName';
      case _ReportColumn.periodDisposable:
        return 'المبلغ القابل للصرف';
      case _ReportColumn.rates:
        return 'النسب';
    }
  }
}

class _MonthFilterDropdown extends StatelessWidget {
  const _MonthFilterDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: value,
        decoration: const InputDecoration(labelText: 'الشهر'),
        items: List.generate(12, (index) {
          final month = index + 1;
          return DropdownMenuItem<int>(
            value: month,
            child: Text(_ReportsPageState._monthName(month)),
          );
        }),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _HorizontalScrollHint extends StatelessWidget {
  const _HorizontalScrollHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.swap_horiz, size: 18, color: Color(0xFF52616F)),
          SizedBox(width: 6),
          Text(
            'اسحب الجدول أفقياً لعرض بقية أعمدة المتابعة',
            style: TextStyle(color: Color(0xFF52616F), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({
    required this.items,
    required this.formatter,
    required this.selectedMonth,
  });

  final List<SectionSummaryItem> items;
  final NumberFormat formatter;
  final int selectedMonth;

  @override
  Widget build(BuildContext context) {
    final totalAllocation = items.fold<double>(
      0,
      (sum, item) => sum + item.allocatedAmount,
    );
    final totalReserved = items.fold<double>(
      0,
      (sum, item) => sum + item.totalReserved,
    );
    final totalSpent = items.fold<double>(
      0,
      (sum, item) => sum + item.totalSpent,
    );
    final totalPeriodDisposable = items.fold<double>(
      0,
      (sum, item) => sum + item.effectivePeriodDisposable(selectedMonth),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _SummaryChip(label: 'السجلات', value: items.length.toString()),
          _SummaryChip(
            label: 'التخصيص',
            value: formatter.format(totalAllocation),
          ),
          _SummaryChip(
            label: 'المحجوز',
            value: formatter.format(totalReserved),
          ),
          _SummaryChip(label: 'المصروف', value: formatter.format(totalSpent)),
          _SummaryChip(
            label: 'القابل للصرف',
            value: formatter.format(totalPeriodDisposable),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: const Color(0xFFEFF6FA),
      side: const BorderSide(color: Color(0xFFC9D6DF)),
    );
  }
}

class _SectionSummaryDataSource extends DataGridSource {
  _SectionSummaryDataSource({
    required this.items,
    required this.formatter,
    required this.selectedMonth,
    required this.grouping,
    required this.columns,
  });

  final List<SectionSummaryItem> items;
  final NumberFormat formatter;
  final int selectedMonth;
  final _ReportGrouping grouping;
  final List<_ReportColumn> columns;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: columns
              .map(
                (column) => DataGridCell<SectionSummaryItem>(
                  columnName: column.key,
                  value: item,
                ),
              )
              .toList(),
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as SectionSummaryItem;
    return DataGridRowAdapter(
      cells: columns
          .map((column) => _GridCell(_cellText(column, item)))
          .toList(),
    );
  }

  String _cellText(_ReportColumn column, SectionSummaryItem item) {
    switch (column) {
      case _ReportColumn.program:
        return item.programName;
      case _ReportColumn.section:
        return grouping == _ReportGrouping.byProgram
            ? item.sectionName
            : '${item.sectionCode} - ${item.sectionName}';
      case _ReportColumn.allocation:
        return formatter.format(item.allocatedAmount);
      case _ReportColumn.reserved:
        return formatter.format(item.totalReserved);
      case _ReportColumn.unreserved:
        return formatter.format(item.remainingAllocation);
      case _ReportColumn.spent:
        return formatter.format(item.totalSpent);
      case _ReportColumn.remainingBySpent:
        return formatter.format(item.effectiveRemainingBySpent());
      case _ReportColumn.monthlyQuota:
        return formatter.format(item.effectiveMonthlyQuota());
      case _ReportColumn.periodAllowed:
        return formatter.format(item.effectivePeriodAllowed(selectedMonth));
      case _ReportColumn.periodDisposable:
        return formatter.format(item.effectivePeriodDisposable(selectedMonth));
      case _ReportColumn.rates:
        return 'حجز ${item.reservationRate.toStringAsFixed(1)}% / صرف ${item.spendingRate.toStringAsFixed(1)}%';
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
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
