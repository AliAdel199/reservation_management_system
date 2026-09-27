import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import '../../../reservations/models/reservation_item.dart';

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.reservations,
    this.initialReservationId,
  });

  final List<ReservationItem> reservations;
  final String? initialReservationId;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _reservationSearchController = TextEditingController();
  ReservationItem? _selectedReservation;
  String _reservationSearch = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialReservationId == null ||
        widget.initialReservationId!.isEmpty) {
      return;
    }

    for (final reservation in widget.reservations) {
      if (reservation.id == widget.initialReservationId) {
        _selectedReservation = reservation;
        _reservationSearchController.text = reservation.reservationNumber;
        _reservationSearch = reservation.reservationNumber;
        break;
      }
    }
  }

  @override
  void dispose() {
    _reservationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final visibleReservations = widget.reservations.where((item) {
      final query = _reservationSearch.trim().toLowerCase();
      if (query.isEmpty) return true;
      final haystack = [
        item.reservationNumber,
        item.title,
        item.programName,
        item.budgetSectionName,
        item.fundingReference,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('إضافة صرف'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'reservation_id': _selectedReservation?.id,
            'expense_date': DateTime.now(),
            'document_date': DateTime.now(),
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (widget.reservations.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9B44C)),
                  ),
                  child: const Text(
                    'لا توجد حجوزات قابلة للصرف. يجب أولاً إرسال الحجز للمراجعة ثم اعتماده من صفحة الحجوزات.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _reservationSearchController,
                enabled: widget.reservations.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'بحث عن الحجز',
                  hintText: 'رقم الحجز، العنوان، الباب، البرنامج، التخصيص',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _reservationSearch = value;
                    _selectedReservation = null;
                  });
                  _formKey.currentState?.fields['reservation_id']?.didChange(
                    null,
                  );
                },
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'reservation_id',
                decoration: const InputDecoration(labelText: 'الحجز'),
                enabled: visibleReservations.isNotEmpty,
                items: visibleReservations
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          '${item.reservationNumber} - ${item.title} - ${item.budgetSectionName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedReservation = null;
                    for (final item in widget.reservations) {
                      if (item.id == value) {
                        _selectedReservation = item;
                        break;
                      }
                    }
                  });
                },
              ),
              if (widget.reservations.isNotEmpty &&
                  visibleReservations.isEmpty) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('لا توجد حجوزات مطابقة للبحث.'),
                ),
              ],
              if (_selectedReservation != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9D6DF)),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text(
                        'مبلغ الحجز: ${currency.format(_selectedReservation!.reservedAmount)}',
                      ),
                      Text(
                        'المصروف سابقاً: ${currency.format(_selectedReservation!.spentAmount)}',
                      ),
                      Text(
                        'المتبقي: ${currency.format(_selectedReservation!.remainingAmount)}',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'expense_number',
                decoration: const InputDecoration(labelText: 'رقم الصرف'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(labelText: 'مبلغ الصرف'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
                  FormBuilderValidators.numeric(errorText: 'أدخل رقماً صحيحاً'),
                  (value) {
                    final amount = double.tryParse(value?.toString() ?? '');
                    final remaining = _selectedReservation?.remainingAmount;
                    if (amount != null &&
                        remaining != null &&
                        amount > remaining) {
                      return 'المبلغ أكبر من المتبقي بالحجز';
                    }
                    return null;
                  },
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'expense_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ الصرف'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderDropdown<String>(
                name: 'payment_method',
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('حوالة مصرفية'),
                  ),
                  DropdownMenuItem(value: 'check', child: Text('صك')),
                  DropdownMenuItem(
                    value: 'electronic',
                    child: Text('دفع إلكتروني'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'document_number',
                decoration: const InputDecoration(labelText: 'رقم المستند'),
              ),
              const SizedBox(height: 12),
              FormBuilderDateTimePicker(
                name: 'document_date',
                inputType: InputType.date,
                format: DateFormat('yyyy-MM-dd'),
                decoration: const InputDecoration(labelText: 'تاريخ المستند'),
                validator: FormBuilderValidators.required(
                  errorText: 'الحقل مطلوب',
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'description',
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف'),
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
        FilledButton(
          onPressed: widget.reservations.isEmpty ? null : _submit,
          child: const Text('حفظ الصرف'),
        ),
      ],
    );
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) return;
    final values = formState.value;
    final rawDate = values['expense_date'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate.toString());
    final rawDocumentDate = values['document_date'];
    final parsedDocumentDate = rawDocumentDate is DateTime
        ? rawDocumentDate
        : DateTime.parse(rawDocumentDate.toString());

    Navigator.of(context).pop({
      'reservation_id': values['reservation_id']?.toString(),
      'expense_number': values['expense_number']?.toString().trim(),
      'amount': double.parse(values['amount'].toString()),
      'expense_date': DateFormat('yyyy-MM-dd').format(parsedDate),
      'payment_method': values['payment_method']?.toString().trim(),
      'document_number': values['document_number']?.toString().trim(),
      'document_date': DateFormat('yyyy-MM-dd').format(parsedDocumentDate),
      'description': values['description']?.toString().trim(),
    });
  }
}
