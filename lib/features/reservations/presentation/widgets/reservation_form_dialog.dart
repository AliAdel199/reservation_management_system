import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../programs/models/program_item.dart';
import '../../models/reservation_item.dart';

class ReservationFormDialog extends StatefulWidget {
  const ReservationFormDialog({
    super.key,
    required this.programs,
    required this.sections,
    this.initialValue,
  });

  final List<ProgramItem> programs;
  final List<BudgetSectionItem> sections;
  final ReservationItem? initialValue;

  @override
  State<ReservationFormDialog> createState() => _ReservationFormDialogState();
}

class _ReservationFormDialogState extends State<ReservationFormDialog> {
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
