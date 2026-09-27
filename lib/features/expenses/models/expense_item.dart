class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.reservationId,
    required this.reservationNumber,
    required this.reservationTitle,
    required this.reservationBeneficiary,
    required this.requesterDepartment,
    required this.contactPhone,
    required this.reservationDescription,
    required this.reservationExecutionNote,
    required this.programName,
    required this.budgetSectionCode,
    required this.budgetSectionFullCode,
    required this.budgetSectionName,
    required this.fundingReference,
    required this.expenseNumber,
    required this.amount,
    required this.expenseStatus,
    required this.expenseDate,
    required this.paymentMethod,
    required this.documentNumber,
    required this.documentDate,
    required this.description,
    required this.createdAt,
    required this.cancelledAt,
    required this.cancelReason,
  });

  final String id;
  final String reservationId;
  final String reservationNumber;
  final String? reservationTitle;
  final String? reservationBeneficiary;
  final String? requesterDepartment;
  final String? contactPhone;
  final String? reservationDescription;
  final String? reservationExecutionNote;
  final String programName;
  final String? budgetSectionCode;
  final String? budgetSectionFullCode;
  final String budgetSectionName;
  final String? fundingReference;
  final String expenseNumber;
  final double amount;
  final String expenseStatus;
  final String expenseDate;
  final String? paymentMethod;
  final String? documentNumber;
  final String? documentDate;
  final String? description;
  final String createdAt;
  final String? cancelledAt;
  final String? cancelReason;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return ExpenseItem(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      reservationNumber: json['reservation_number'] as String,
      reservationTitle: json['reservation_title']?.toString(),
      reservationBeneficiary: json['reservation_beneficiary']?.toString(),
      requesterDepartment: json['requester_department']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      reservationDescription: json['reservation_description']?.toString(),
      reservationExecutionNote: json['reservation_execution_note']?.toString(),
      programName: json['program_name'] as String,
      budgetSectionCode: json['budget_section_code']?.toString(),
      budgetSectionFullCode: json['budget_section_full_code']?.toString(),
      budgetSectionName: json['budget_section_name'] as String,
      fundingReference: json['funding_reference']?.toString(),
      expenseNumber: json['expense_number'] as String,
      amount: parseDouble(json['amount']),
      expenseStatus: json['expense_status'] as String,
      expenseDate: json['expense_date']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString(),
      documentNumber: json['document_number']?.toString(),
      documentDate: json['document_date']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      cancelledAt: json['cancelled_at']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
    );
  }
}
