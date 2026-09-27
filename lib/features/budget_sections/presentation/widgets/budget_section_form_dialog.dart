import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../programs/models/program_item.dart';
import '../../models/budget_section_item.dart';

class BudgetSectionFormDialog extends StatefulWidget {
  const BudgetSectionFormDialog({
    super.key,
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
  State<BudgetSectionFormDialog> createState() => _BudgetSectionDialogState();
}

class _BudgetSectionDialogState extends State<BudgetSectionFormDialog> {
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
