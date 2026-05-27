import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
                    final summary = _BudgetSectionsPageSummary.fromItems(
                      state.result.items,
                    );
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SummaryTitle(
                                title: 'ملخص الأبواب',
                                subtitle:
                                    'حسب الفلاتر الحالية وبلا تكرار للمجاميع الهرمية',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _BudgetSummaryCard(
                                    title: 'إجمالي الأبواب',
                                    value: state.result.pagination.total
                                        .toString(),
                                    subtitle:
                                        '${summary.activeCount} فعال / ${summary.inactiveCount} معطل',
                                  ),
                                  _BudgetSummaryCard(
                                    title: 'الأبواب النهائية',
                                    value: summary.postableCount.toString(),
                                    subtitle: 'تقبل التخصيص والحجز والصرف',
                                  ),
                                  _BudgetSummaryCard(
                                    title: 'الأبواب التجميعية',
                                    value: summary.parentCount.toString(),
                                    subtitle:
                                        '${summary.childrenCount} ابن مباشر داخل النتائج',
                                  ),
                                  _BudgetSummaryCard(
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
                            source: _BudgetSectionsDataSource(
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
                                label: _GridHeader('البرنامج'),
                              ),
                              GridColumn(
                                columnName: 'year',
                                width: 145,
                                label: _GridHeader('السنة'),
                              ),
                              GridColumn(
                                columnName: 'full_code',
                                width: 150,
                                label: _GridHeader('الكود الكامل'),
                              ),
                              GridColumn(
                                columnName: 'name',
                                width: 360,
                                label: _GridHeader('الاسم'),
                              ),
                              GridColumn(
                                columnName: 'type',
                                width: 100,
                                label: _GridHeader('النوع'),
                              ),
                              GridColumn(
                                columnName: 'children',
                                width: 85,
                                label: _GridHeader('الأبناء'),
                              ),
                              GridColumn(
                                columnName: 'status',
                                width: 95,
                                label: _GridHeader('الحالة'),
                              ),
                              GridColumn(
                                columnName: 'allocated',
                                width: 145,
                                label: _GridHeader('المباشر'),
                              ),
                              GridColumn(
                                columnName: 'total',
                                width: 145,
                                label: _GridHeader('المجموع'),
                              ),
                              GridColumn(
                                columnName: 'actions',
                                width: 120,
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
      builder: (context) => _BudgetSectionDialog(
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
      builder: (context) => _BudgetSectionDialog(
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

class _BudgetSectionDialog extends StatefulWidget {
  const _BudgetSectionDialog({
    required this.programs,
    required this.fiscalYears,
    required this.sections,
    this.initialValue,
  });

  final List<ProgramItem> programs;
  final List<FiscalYearItem> fiscalYears;
  final List<BudgetSectionItem> sections;
  final BudgetSectionItem? initialValue;

  @override
  State<_BudgetSectionDialog> createState() => _BudgetSectionDialogState();
}

class _BudgetSectionDialogState extends State<_BudgetSectionDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _programId;
  String? _fiscalYearId;
  bool _isPostable = true;

  @override
  void initState() {
    super.initState();
    _programId = widget.initialValue?.programId;
    _fiscalYearId = widget.initialValue?.fiscalYearId;
    _isPostable = widget.initialValue?.isPostable ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;
    final dialogHeight = (MediaQuery.sizeOf(context).height * 0.68).clamp(
      420.0,
      720.0,
    );

    return AlertDialog(
      title: Text(
        item == null ? 'إضافة باب بتخصيص سنوي' : 'تعديل الباب والتخصيص السنوي',
      ),
      content: SizedBox(
        width: 560,
        height: dialogHeight.toDouble(),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'program_id': item?.programId,
            'fiscal_year_id': item?.fiscalYearId,
            'parent_id': item?.parentId,
            'code': item?.code,
            'name': item?.name,
            'description': item?.description,
            'allocated_amount': item?.allocatedAmount.toStringAsFixed(0),
            'is_postable': item?.isPostable ?? true,
            'sort_order': item?.sortOrder.toString(),
            'is_active': item?.isActive ?? true,
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      _formKey.currentState?.fields['parent_id']?.didChange(
                        null,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                FormBuilderDropdown<String>(
                  name: 'fiscal_year_id',
                  decoration: const InputDecoration(labelText: 'السنة المالية'),
                  items: widget.fiscalYears
                      .map(
                        (year) => DropdownMenuItem<String>(
                          value: year.id,
                          child: Text(year.name),
                        ),
                      )
                      .toList(),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _fiscalYearId = value;
                      _formKey.currentState?.fields['parent_id']?.didChange(
                        null,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                FormBuilderDropdown<String>(
                  name: 'parent_id',
                  decoration: const InputDecoration(
                    labelText: 'الباب الأب',
                    helperText: 'اتركه فارغاً إذا كان باباً رئيسياً.',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('بدون باب أب'),
                    ),
                    ..._availableParents.map(
                      (section) => DropdownMenuItem<String>(
                        value: section.id,
                        child: Text(
                          '${_treePrefix(section.level)}${section.fullCode} - ${section.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'code',
                  decoration: const InputDecoration(labelText: 'رمز الباب'),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'name',
                  decoration: const InputDecoration(labelText: 'اسم الباب'),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFD4E5)),
                  ),
                  child: const Text(
                    'التخصيص السنوي هو سقف الباب خلال السنة المالية، ويعتمد عليه النظام في منع الحجز الزائد وحساب التقارير والداشبورد.',
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'allocated_amount',
                  enabled: _isPostable,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'التخصيص السنوي المباشر',
                    prefixText: 'د.ع ',
                    helperText: 'مثال: 5000000 أو 5,000,000',
                  ),
                  validator: _validateAnnualAllocation,
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'sort_order',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ترتيب العرض',
                    helperText:
                        'اختياري: رقم أصغر يظهر أولاً داخل نفس المستوى.',
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderSwitch(
                  name: 'is_postable',
                  title: const Text('باب نهائي يقبل التخصيص والحجز والصرف'),
                  onChanged: (value) {
                    setState(() {
                      _isPostable = value ?? true;
                      if (!_isPostable) {
                        _formKey.currentState?.fields['allocated_amount']
                            ?.didChange('0');
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                FormBuilderSwitch(name: 'is_active', title: const Text('فعال')),
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
    if (formState == null || !formState.saveAndValidate()) {
      return;
    }

    final values = formState.value;
    final annualAllocation = _parseAnnualAllocation(
      values['allocated_amount']?.toString(),
    );

    Navigator.of(context).pop({
      'program_id': values['program_id']?.toString(),
      'fiscal_year_id': values['fiscal_year_id']?.toString(),
      'parent_id': values['parent_id']?.toString(),
      'code': values['code']?.toString().trim(),
      'name': values['name']?.toString().trim(),
      'description': values['description']?.toString().trim(),
      'allocated_amount': values['is_postable'] == false ? 0 : annualAllocation,
      'is_postable': values['is_postable'] as bool? ?? true,
      'sort_order': int.tryParse(values['sort_order']?.toString() ?? '') ?? 0,
      'is_active': values['is_active'] as bool? ?? true,
    });
  }

  List<BudgetSectionItem> get _availableParents {
    return widget.sections.where((section) {
        if (widget.initialValue?.id == section.id) return false;
        if (_programId != null && section.programId != _programId) return false;
        if (_fiscalYearId != null && section.fiscalYearId != _fiscalYearId) {
          return false;
        }
        final currentPath = widget.initialValue?.path;
        if (currentPath != null &&
            section.path != null &&
            section.path!.startsWith('$currentPath/')) {
          return false;
        }
        return section.isActive;
      }).toList()
      ..sort((a, b) => (a.path ?? a.fullCode).compareTo(b.path ?? b.fullCode));
  }

  String _treePrefix(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return List.filled(safeLevel - 1, '  ').join();
  }

  String? _validateAnnualAllocation(String? value) {
    final normalized = _normalizeAnnualAllocation(value);
    if (normalized.isEmpty) {
      return 'الحقل مطلوب';
    }

    final amount = double.tryParse(normalized);
    if (amount == null) {
      return 'أدخل مبلغاً صحيحاً';
    }

    if (amount < 0) {
      return 'التخصيص السنوي لا يمكن أن يكون سالباً';
    }

    return null;
  }

  double _parseAnnualAllocation(String? value) {
    return double.parse(_normalizeAnnualAllocation(value));
  }

  String _normalizeAnnualAllocation(String? value) {
    // تعليق عربي: نسمح للمستخدم بكتابة الفواصل أو رمز العملة داخل المبلغ.
    return (value ?? '')
        .replaceAll(',', '')
        .replaceAll('د.ع', '')
        .replaceAll(' ', '')
        .trim();
  }
}

class _BudgetSectionsDataSource extends DataGridSource {
  _BudgetSectionsDataSource({
    required this.items,
    required this.formatter,
    required this.collapsedIds,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final List<BudgetSectionItem> items;
  final NumberFormat formatter;
  final Set<String> collapsedIds;
  final ValueChanged<BudgetSectionItem> onToggle;
  final Future<void> Function(BudgetSectionItem item)? onEdit;
  final Future<void> Function(BudgetSectionItem item)? onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<BudgetSectionItem>(columnName: 'program', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'year', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'full_code',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'name', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'type', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'children',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'status', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'allocated',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'total', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as BudgetSectionItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.programName),
        _GridCell(item.fiscalYearName ?? item.fiscalYear.toString()),
        _GridCell(item.fullCode),
        _TreeNameCell(
          item: item,
          isCollapsed: collapsedIds.contains(item.id),
          onToggle: onToggle,
        ),
        _GridCell(item.isPostable ? 'نهائي' : 'تجميعي'),
        _GridCell(item.childrenCount.toString()),
        _GridCell(item.isActive ? 'فعال' : 'معطل'),
        _GridCell(formatter.format(item.allocatedAmount)),
        _GridCell(formatter.format(item.totalAllocatedAmount)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (onEdit != null)
                IconButton(
                  onPressed: () => onEdit!(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: () => onDelete!(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (onEdit == null && onDelete == null) const Text('معاينة'),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetSectionsPageSummary {
  const _BudgetSectionsPageSummary({
    required this.activeCount,
    required this.inactiveCount,
    required this.postableCount,
    required this.parentCount,
    required this.childrenCount,
    required this.postableAllocationTotal,
  });

  final int activeCount;
  final int inactiveCount;
  final int postableCount;
  final int parentCount;
  final int childrenCount;
  final double postableAllocationTotal;

  factory _BudgetSectionsPageSummary.fromItems(List<BudgetSectionItem> items) {
    var activeCount = 0;
    var inactiveCount = 0;
    var postableCount = 0;
    var parentCount = 0;
    var childrenCount = 0;
    var postableAllocationTotal = 0.0;

    for (final item in items) {
      if (item.isActive) {
        activeCount++;
      } else {
        inactiveCount++;
      }

      childrenCount += item.childrenCount;
      if (item.isPostable) {
        postableCount++;
        postableAllocationTotal += item.allocatedAmount;
      } else {
        parentCount++;
      }
    }

    return _BudgetSectionsPageSummary(
      activeCount: activeCount,
      inactiveCount: inactiveCount,
      postableCount: postableCount,
      parentCount: parentCount,
      childrenCount: childrenCount,
      postableAllocationTotal: postableAllocationTotal,
    );
  }
}

class _SummaryTitle extends StatelessWidget {
  const _SummaryTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF123B56),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _GridHeader extends StatelessWidget {
  const _GridHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
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
          child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ),
    );
  }
}

class _TreeNameCell extends StatelessWidget {
  const _TreeNameCell({
    required this.item,
    required this.isCollapsed,
    required this.onToggle,
  });

  final BudgetSectionItem item;
  final bool isCollapsed;
  final ValueChanged<BudgetSectionItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final indent = ((item.level - 1).clamp(0, 12) * 18).toDouble();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 12 + indent,
        end: 12,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: item.childrenCount > 0 ? () => onToggle(item) : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                item.childrenCount > 0
                    ? (isCollapsed
                          ? Icons.keyboard_arrow_left_rounded
                          : Icons.keyboard_arrow_down_rounded)
                    : Icons.circle,
                size: item.childrenCount > 0 ? 22 : 8,
                color: item.isPostable
                    ? const Color(0xFF1A7F5A)
                    : const Color(0xFF0D4A73),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: '${item.fullCode} - ${item.name}',
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
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
