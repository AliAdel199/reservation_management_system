import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../models/funding_item.dart';
import '../controllers/fundings_controller.dart';
import '../../../../shared/widgets/grid_text_cells.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../widgets/funding_form_dialog.dart';
import '../widgets/transfer_allocation_dialog.dart';
import '../widgets/funding_movements_dialog.dart';
import '../widgets/fundings_grid.dart';

class FundingsPage extends ConsumerStatefulWidget {
  const FundingsPage({super.key});

  @override
  ConsumerState<FundingsPage> createState() => _FundingsPageState();
}

class _FundingsPageState extends ConsumerState<FundingsPage> {
  final _searchController = TextEditingController();
  String? _selectedProgramId;
  String? _selectedBudgetSectionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fundingsState = ref.watch(fundingsControllerProvider);
    final programsLookup = ref.watch(programLookupProvider);
    final budgetSectionsLookup = ref.watch(allBudgetSectionsLookupProvider);
    final fiscalYearsLookup = ref.watch(fiscalYearsLookupProvider);
    final activeFiscalYear = _activeFiscalYear(fiscalYearsLookup.asData?.value);

    ref.listen(fundingsControllerProvider, (previous, next) {
      if (next.hasError && next.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    final availableSections =
        budgetSectionsLookup.asData?.value
            .where(
              (section) => _selectedProgramId == null
                  ? true
                  : section.programId == _selectedProgramId,
            )
            .toList() ??
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
                      'التخصيصات المالية',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة التخصيصات المالية وربطها بالبرامج والأبواب مع تسجيلها داخل Ledger المالي.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: budgetSectionsLookup.hasValue
                        ? () => _openMovementsReport(
                            programsLookup.asData?.value ?? const [],
                            budgetSectionsLookup.requireValue,
                          )
                        : null,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('تقرير الحركة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: budgetSectionsLookup.hasValue
                        ? () => _openTransferDialog(
                            budgetSectionsLookup.requireValue,
                          )
                        : null,
                    icon: const Icon(Icons.swap_horiz_outlined),
                    label: const Text('مناقلة'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        programsLookup.hasValue && budgetSectionsLookup.hasValue
                        ? () => _openCreateDialog(
                            programsLookup.requireValue,
                            budgetSectionsLookup.requireValue,
                            activeFiscalYear: activeFiscalYear,
                          )
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تخصيص'),
                  ),
                ],
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
                    labelText: 'بحث بالمرجع أو البرنامج أو الباب',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 250,
                child: programsLookup.when(
                  data: (programs) => DropdownButtonFormField<String>(
                    initialValue: _selectedProgramId,
                    decoration: const InputDecoration(labelText: 'البرنامج'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('كل البرامج'),
                      ),
                      ...programs.map(
                        (program) => DropdownMenuItem<String>(
                          value: program.id,
                          child: Text(program.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedProgramId = value == '' ? null : value;
                      _selectedBudgetSectionId = null;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('تعذر تحميل البرامج'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBudgetSectionId,
                  decoration: const InputDecoration(labelText: 'الباب'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('كل الأبواب'),
                    ),
                    ...availableSections.map(
                      (section) => DropdownMenuItem<String>(
                        value: section.id,
                        child: Text('${section.code} - ${section.name}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedBudgetSectionId = value == '' ? null : value;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _applyFilters,
                child: const Text('تطبيق'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: fundingsState,
                onRetry: () =>
                    ref.read(fundingsControllerProvider.notifier).refresh(),
                data: (state) => Column(
                  children: [
                    Expanded(
                      child: SfDataGrid(
                        source: FundingsDataSource(
                          items: state.result.items,
                          formatter: NumberFormat.currency(
                            locale: 'ar_IQ',
                            symbol: 'د.ع',
                            decimalDigits: 0,
                          ),
                          onEdit: (item) async {
                            try {
                              if (!programsLookup.hasValue ||
                                  !budgetSectionsLookup.hasValue) {
                                return;
                              }
                              await _openEditDialog(
                                programsLookup.requireValue,
                                budgetSectionsLookup.requireValue,
                                item,
                              );
                            } catch (error) {
                              if (!mounted) return;
                              _showError(_friendlyFundingError(error));
                            }
                          },
                        ),
                        columnWidthMode: ColumnWidthMode.auto,
                        columns: [
                          GridColumn(
                            columnName: 'reference',
                            label: GridHeaderText('مرجع التخصيص'),
                          ),
                          GridColumn(
                            columnName: 'program',
                            label: GridHeaderText('البرنامج'),
                          ),
                          GridColumn(
                            columnName: 'section',
                            label: GridHeaderText('الباب'),
                          ),
                          GridColumn(
                            columnName: 'year',
                            label: GridHeaderText('السنة'),
                          ),
                          GridColumn(
                            columnName: 'initial_amount',
                            label: GridHeaderText('التخصيص البدائي'),
                          ),
                          GridColumn(
                            columnName: 'current_amount',
                            label: GridHeaderText('التخصيص الحالي'),
                          ),
                          GridColumn(
                            columnName: 'reserved_amount',
                            label: GridHeaderText('المحجوز'),
                          ),
                          GridColumn(
                            columnName: 'spent_amount',
                            label: GridHeaderText('المصروف'),
                          ),
                          GridColumn(
                            columnName: 'available_amount',
                            label: GridHeaderText('المتبقي المتاح'),
                          ),
                          GridColumn(
                            columnName: 'actions',
                            label: GridHeaderText('إجراءات'),
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
                                .read(fundingsControllerProvider.notifier)
                                .changePage(state.result.pagination.page - 1)
                          : null,
                      onNext:
                          state.result.pagination.page <
                              state.result.pagination.totalPages
                          ? () => ref
                                .read(fundingsControllerProvider.notifier)
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

  Future<void> _openCreateDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections, {
    int? activeFiscalYear,
  }) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FundingFormDialog(
        programs: programs,
        sections: sections,
        activeFiscalYear: activeFiscalYear,
      ),
    );

    if (payload == null || !mounted) return;
    try {
      await ref.read(fundingsControllerProvider.notifier).create(payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تمت إضافة التخصيص بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  Future<void> _openEditDialog(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
    FundingItem item,
  ) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FundingFormDialog(
        programs: programs,
        sections: sections,
        initialValue: item,
      ),
    );

    if (payload == null || !mounted) return;
    try {
      await ref
          .read(fundingsControllerProvider.notifier)
          .updateFunding(item.id, payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تم تحديث التخصيص بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  int? _activeFiscalYear(List<FiscalYearItem>? fiscalYears) {
    if (fiscalYears == null) return null;
    for (final fiscalYear in fiscalYears) {
      if (fiscalYear.isActive) return fiscalYear.year;
    }
    return null;
  }

  Future<void> _openTransferDialog(List<BudgetSectionItem> sections) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TransferAllocationDialog(sections: sections),
    );

    if (payload == null || !mounted) return;
    try {
      await ref
          .read(fundingsControllerProvider.notifier)
          .transferAllocation(payload);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      if (!mounted) return;
      _showSuccess('تمت المناقلة بين التخصيصات بنجاح.');
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyFundingError(error));
    }
  }

  Future<void> _openMovementsReport(
    List<ProgramItem> programs,
    List<BudgetSectionItem> sections,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FundingMovementsDialog(
        repository: ref.read(fundingsRepositoryProvider),
        programs: programs,
        sections: sections,
      ),
    );
  }

  void _applyFilters() {
    ref
        .read(fundingsControllerProvider.notifier)
        .applyFilters(
          search: _searchController.text,
          programId: _selectedProgramId,
          budgetSectionId: _selectedBudgetSectionId,
        );
  }

  String _friendlyFundingError(Object error) {
    if (error is AppException) {
      if (error.code == 'FUNDING_REFERENCE_EXISTS') {
        return 'مرجع التخصيص مستخدم مسبقاً. غيّر المرجع أو تأكد من السجل الصحيح.';
      }
      return error.message;
    }
    return error.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
