import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import '../../../budget_sections/models/budget_section_item.dart';

class TransferAllocationDialog extends StatefulWidget {
  const TransferAllocationDialog({super.key, required this.sections});

  final List<BudgetSectionItem> sections;

  @override
  State<TransferAllocationDialog> createState() =>
      _TransferAllocationDialogState();
}

class _TransferAllocationDialogState extends State<TransferAllocationDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final sections = widget.sections
        .where((section) => section.isPostable && section.isActive)
        .toList();

    return AlertDialog(
      title: const Text('مناقلة بين التخصيصات'),
      content: SizedBox(
        width: 620,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'reference': 'TR-${DateTime.now().millisecondsSinceEpoch}',
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderDropdown<String>(
                name: 'from_budget_section_id',
                decoration: const InputDecoration(labelText: 'من باب'),
                items: sections
                    .map(
                      (section) => DropdownMenuItem(
                        value: section.id,
                        child: Text(
                          '${section.fullCode} - ${section.name} (${currency.format(section.allocatedAmount)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'to_budget_section_id',
                decoration: const InputDecoration(labelText: 'إلى باب'),
                items: sections
                    .map(
                      (section) => DropdownMenuItem(
                        value: section.id,
                        child: Text(
                          '${section.fullCode} - ${section.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(labelText: 'مبلغ المناقلة'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'reference',
                decoration: const InputDecoration(labelText: 'مرجع المناقلة'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
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
        FilledButton(onPressed: _submit, child: const Text('تنفيذ المناقلة')),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    if (values['from_budget_section_id'] == values['to_budget_section_id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن المناقلة لنفس الباب.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'from_budget_section_id': values['from_budget_section_id']?.toString(),
      'to_budget_section_id': values['to_budget_section_id']?.toString(),
      'amount': double.parse(values['amount'].toString()),
      'reference': values['reference']?.toString().trim(),
      'notes': values['notes']?.toString().trim(),
    });
  }
}
