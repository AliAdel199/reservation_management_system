import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../programs/models/program_item.dart';
import '../../models/funding_item.dart';

class FundingFormDialog extends StatefulWidget {
  const FundingFormDialog({
    super.key,
    required this.programs,
    required this.sections,
    this.initialValue,
    this.activeFiscalYear,
  });

  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;
  final FundingItem? initialValue;
  final int? activeFiscalYear;

  @override
  State<FundingFormDialog> createState() => _FundingDialogState();
}

class _FundingDialogState extends State<FundingFormDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _programId;

  @override
  void initState() {
    super.initState();
    _programId = widget.initialValue?.programId;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.initialValue;
    final availableSections = widget.sections
        .where(
          (section) =>
              _programId == null ? true : section.programId == _programId,
        )
        .toList();

    return AlertDialog(
      title: Text(item == null ? 'إضافة تخصيص مالي' : 'تعديل تخصيص مالي'),
      content: SizedBox(
        width: 560,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'program_id': item?.programId,
            'budget_section_id': item?.budgetSectionId,
            'funding_reference': item?.fundingReference,
            'fiscal_year': (item?.fiscalYear ?? widget.activeFiscalYear)
                ?.toString(),
            'allocated_amount': item?.allocatedAmount.toStringAsFixed(0),
            'notes': item?.notes,
          },
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
                  });
                  _formKey.currentState?.fields['budget_section_id']?.didChange(
                    null,
                  );
                },
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'budget_section_id',
                decoration: const InputDecoration(labelText: 'الباب'),
                items: availableSections
                    .where((section) => section.isPostable && section.isActive)
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
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'funding_reference',
                decoration: const InputDecoration(labelText: 'مرجع التخصيص'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'fiscal_year',
                decoration: const InputDecoration(
                  labelText: 'السنة المالية',
                  helperText: 'تُملأ تلقائياً من السنة المالية الفعالة',
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.integer(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'allocated_amount',
                decoration: const InputDecoration(labelText: 'مبلغ التخصيص'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                ]),
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
    Navigator.of(context).pop({
      'program_id': values['program_id']?.toString(),
      'budget_section_id': values['budget_section_id']?.toString(),
      'funding_reference': values['funding_reference']?.toString().trim(),
      'fiscal_year': int.parse(values['fiscal_year'].toString()),
      'allocated_amount': double.parse(values['allocated_amount'].toString()),
      'notes': values['notes']?.toString().trim(),
    });
  }
}
