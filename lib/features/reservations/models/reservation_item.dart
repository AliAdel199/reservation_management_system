class ReservationItem {
  const ReservationItem({
    required this.id,
    required this.reservationNumber,
    required this.programId,
    required this.programCode,
    required this.programName,
    required this.budgetSectionId,
    required this.budgetSectionCode,
    required this.budgetSectionName,
    required this.fundingId,
    required this.fundingReference,
    required this.title,
    required this.description,
    required this.beneficiary,
    required this.executionNote,
    required this.requesterDepartment,
    required this.contactPhone,
    required this.reservedAmount,
    required this.workflowStatus,
    required this.reservationDate,
    required this.createdAt,
    required this.approvedAt,
    required this.cancelledAt,
    required this.closedAt,
    required this.fundingAvailableBalance,
    required this.spentAmount,
    required this.remainingAmount,
    required this.executionStatus,
  });

  final String id;
  final String reservationNumber;
  final String programId;
  final String programCode;
  final String programName;
  final String budgetSectionId;
  final String budgetSectionCode;
  final String budgetSectionName;
  final String fundingId;
  final String fundingReference;
  final String title;
  final String? description;
  final String? beneficiary;
  final String? executionNote;
  final String? requesterDepartment;
  final String? contactPhone;
  final double reservedAmount;
  final String workflowStatus;
  final String reservationDate;
  final String createdAt;
  final String? approvedAt;
  final String? cancelledAt;
  final String? closedAt;
  final double fundingAvailableBalance;
  final double spentAmount;
  final double remainingAmount;
  final String executionStatus;

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return ReservationItem(
      id: json['id'] as String,
      reservationNumber: json['reservation_number'] as String,
      programId: json['program_id'] as String,
      programCode: json['program_code'] as String,
      programName: json['program_name'] as String,
      budgetSectionId: json['budget_section_id'] as String,
      budgetSectionCode: json['budget_section_code'] as String,
      budgetSectionName: json['budget_section_name'] as String,
      fundingId: json['funding_id'] as String,
      fundingReference: json['funding_reference'] as String,
      title: json['title'] as String,
      description: json['description']?.toString(),
      beneficiary: json['beneficiary']?.toString(),
      executionNote: json['execution_note']?.toString(),
      requesterDepartment: json['requester_department']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      reservedAmount: parseDouble(json['reserved_amount']),
      workflowStatus: json['workflow_status'] as String,
      reservationDate: json['reservation_date']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      approvedAt: json['approved_at']?.toString(),
      cancelledAt: json['cancelled_at']?.toString(),
      closedAt: json['closed_at']?.toString(),
      fundingAvailableBalance: parseDouble(json['funding_available_balance']),
      spentAmount: parseDouble(json['spent_amount']),
      remainingAmount: parseDouble(json['remaining_amount']),
      executionStatus: json['execution_status']?.toString() ?? 'not_executed',
    );
  }
}
