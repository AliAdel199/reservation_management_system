import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../models/budget_section_item.dart';
import '../controllers/budget_sections_controller.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../shared/widgets/summary_title.dart';
import '../widgets/budget_section_form_dialog.dart';
import '../widgets/budget_sections_grid.dart';
import '../widgets/budget_sections_summary.dart';

class BudgetSectionsPage extends ConsumerStatefulWidget {
  const BudgetSectionsPage({super.key});

  @override
  ConsumerState<BudgetSectionsPage> createState() => _BudgetSectionsPageState();
}

class _BudgetSectionsPageState extends ConsumerState<BudgetSectionsPage> {
  final _searchController = TextEditingController();
  final Set<String> _collapsedSectionIds = <String>{};
  String? _selectedProgramId;
  String? _selectedFiscalYearId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetSectionsState = ref.watch(budgetSectionsControllerProvider);
    final programLookupState = ref.watch(programLookupProvider);
    final fiscalYearsState = ref.watch(fiscalYearsLookupProvider);
    final sectionsLookupState = ref.watch(allBudgetSectionsLookupProvider);
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canAdd = currentUser?.canAddBudgetSections ?? false;
    final canEdit = currentUser?.canEditBudgetSections ?? false;
    final canDelete = currentUser?.canDeleteBudgetSections ?? false;
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );

    ref.listen(budgetSectionsControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

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
                        'الأبواب',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة الأبواب وربطها بالبرامج مع تحديد التخصيص السنوي لكل باب.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      canAdd &&
                          programLookupState.hasValue &&
                          fiscalYearsState.hasValue
                      ? () => _openCreateDialog(
                          programLookupState.requireValue,
                          fiscalYearsState.requireValue,
                          sectionsLookupState.asData?.value ?? const [],
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة باب'),
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
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالرمز أو الاسم أو البرنامج',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: programLookupState.when(
                    data: (programs) => DropdownButtonFormField<String>(
                      initialValue: _selectedProgramId,
                      isExpanded: true,
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
                      onChanged: (value) {
                        setState(() {
                          _selectedProgramId = value == '' ? null : value;
                        });
                        _applyFilters();
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('تعذر تحميل البرامج'),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: _lookupDropdown<FiscalYearItem>(
                    label: 'السنة المالية',
                    value: _selectedFiscalYearId,
                    items: fiscalYearsState.asData?.value ?? const [],
                    itemValue: (item) => item.id,
                    itemText: (item) => item.name,
                    onChanged: (value) {
                      setState(() => _selectedFiscalYearId = value);
                      _applyFilters();
                    },
                  ),
                ),
                OutlinedButton(
                  onPressed: _applyFilters,
                  child: const Text('تطبيق'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_collapsedSectionIds.clear),
                  icon: const Icon(Icons.unfold_more_rounded),
                  label: const Text('فتح الشجرة'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 700,
              child: Card(
                child: AsyncValueView(
                  value: budgetSectionsState,
                  onRetry: () => ref
                      .read(budgetSectionsControllerProvider.notifier)
                      .refresh(),
                  data: (state) {
                    final visibleItems = _visibleTreeItems(state.result.items);
                    final summary = BudgetSectionsPageSummary.fromItems(
                      state.result.items,
                    );
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SummaryTitle(
                                title: 'ملخص الأبواب',
                                subtitle:
                                    'حسب الفلاتر الحالية وبلا تكرار للمجاميع الهرمية',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  BudgetSummaryCard(
                                    title: 'إجمالي الأبواب',
                                    value: state.result.pagination.total
                                        .toString(),
                                    subtitle:
                                        '${summary.activeCount} فعال / ${summary.inactiveCount} معطل',
                                  ),
                                  BudgetSummaryCard(
                                    title: 'الأبواب النهائية',
                                    value: summary.postableCount.toString(),
                                    subtitle: 'تقبل التخصيص والحجز والصرف',
                                  ),
                                  BudgetSummaryCard(
                                    title: 'الأبواب التجميعية',
                                    value: summary.parentCount.toString(),
                                    subtitle:
                                        '${summary.childrenCount} ابن مباشر داخل النتائج',
                                  ),
                                  BudgetSummaryCard(
                                    title: 'التخصيص السنوي',
                                    value: currency.format(
                                      summary.postableAllocationTotal,
                                    ),
                                    subtitle: '',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        Expanded(
                          child: SfDataGrid(
                            source: BudgetSectionsDataSource(
                              items: visibleItems,
                              formatter: currency,
                              collapsedIds: _collapsedSectionIds,
                              onToggle: _toggleTreeNode,
                              onEdit: canEdit
                                  ? (item) async {
                                      if (!programLookupState.hasValue ||
                                          !fiscalYearsState.hasValue) {
                                        return;
                                      }
                                      await _openEditDialog(
                                        programLookupState.requireValue,
                                        fiscalYearsState.requireValue,
                                        sectionsLookupState.asData?.value ??
                                            state.result.items,
                                        item,
                                      );
                                    }
                                  : null,
                              onDelete: canDelete ? _deleteBudgetSection : null,
                            ),
                            // تعليق عربي: نعطي اسم الباب مساحة أكبر لأن الشجرة الهرمية
                            // تحتاج إزاحة للمستويات واسم واضح للمستخدم.
                            columnWidthMode: ColumnWidthMode.none,
                            columns: [
                              GridColumn(
                                columnName: 'program',
                                width: 150,
                                label: BudgetSectionGridHeader('البرنامج'),
                              ),
                              GridColumn(
                                columnName: 'year',
                                width: 145,
                                label: BudgetSectionGridHeader('السنة'),
                              ),
                              GridColumn(
                                columnName: 'full_code',
                                width: 150,
                                label: BudgetSectionGridHeader('الكود الكامل'),
                              ),
                              GridColumn(
                                columnName: 'name',
                                width: 360,
                                label: BudgetSectionGridHeader('الاسم'),
                              ),
                              GridColumn(
                                columnName: 'type',
                                width: 100,
                                label: BudgetSectionGridHeader('النوع'),
                              ),
                              GridColumn(
                                columnName: 'children',
                                width: 85,
                                label: BudgetSectionGridHeader('الأبناء'),
                              ),
                              GridColumn(
                                columnName: 'status',
                                width: 95,
                                label: BudgetSectionGridHeader('الحالة'),
                              ),
                              GridColumn(
                                columnName: 'allocated',
                                width: 145,
                                label: BudgetSectionGridHeader('المباشر'),
                              ),
                              GridColumn(
                                columnName: 'total',
                                width: 145,
                                label: BudgetSectionGridHeader('المجموع'),
                              ),
                              GridColumn(
                                columnName: 'actions',
                                width: 120,
                                label: BudgetSectionGridHeader('إجراءات'),
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
                                      budgetSectionsControllerProvider.notifier,
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
                                      budgetSectionsControllerProvider.notifier,
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
      onChanged: (value) => onChanged(value == '' ? null : value),
    );
  }

  Future<void> _openCreateDialog(
    List<ProgramItem> programs,
    List<FiscalYearItem> fiscalYears,
    List<BudgetSectionItem> sections,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BudgetSectionFormDialog(
        programs: programs,
        fiscalYears: fiscalYears,
        sections: sections,
      ),
    );

    if (payload == null || !mounted) {
      return;
    }

    await ref.read(budgetSectionsControllerProvider.notifier).create(payload);
  }

  Future<void> _openEditDialog(
    List<ProgramItem> programs,
    List<FiscalYearItem> fiscalYears,
    List<BudgetSectionItem> sections,
    BudgetSectionItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BudgetSectionFormDialog(
        programs: programs,
        fiscalYears: fiscalYears,
        sections: sections,
        initialValue: item,
      ),
    );

    if (payload == null || !mounted) {
      return;
    }

    await ref
        .read(budgetSectionsControllerProvider.notifier)
        .updateBudgetSection(item.id, payload);
  }

  Future<void> _deleteBudgetSection(BudgetSectionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الباب'),
        content: Text(
          'هل تريد حذف الباب "${item.name}"؟\n'
          'سيتم منع الحذف إذا كان مرتبطاً بحجوزات أو تخصيصات أو حركات مالية.',
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

    await ref.read(budgetSectionsControllerProvider.notifier).remove(item.id);
  }

  void _applyFilters() {
    ref
        .read(budgetSectionsControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          programId: _selectedProgramId,
          fiscalYearId: _selectedFiscalYearId,
          budgetTypeId: '',
        );
  }

  List<BudgetSectionItem> _visibleTreeItems(List<BudgetSectionItem> items) {
    return items.where((item) {
      final pathParts = item.path?.split('/') ?? const <String>[];
      for (final ancestorId in pathParts) {
        if (ancestorId == item.id) continue;
        if (_collapsedSectionIds.contains(ancestorId)) return false;
      }
      return true;
    }).toList();
  }

  void _toggleTreeNode(BudgetSectionItem item) {
    if (item.childrenCount == 0) return;
    setState(() {
      if (_collapsedSectionIds.contains(item.id)) {
        _collapsedSectionIds.remove(item.id);
      } else {
        _collapsedSectionIds.add(item.id);
      }
    });
  }
}
