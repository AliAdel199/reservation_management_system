class Reservation {
  const Reservation({
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

  factory Reservation.fromRow(Map<String, dynamic> row) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return Reservation(
      id: row['id'].toString(),
      reservationNumber: row['reservation_number'].toString(),
      programId: row['program_id'].toString(),
      programCode: row['program_code'].toString(),
      programName: row['program_name'].toString(),
      budgetSectionId: row['budget_section_id'].toString(),
      budgetSectionCode: row['budget_section_code'].toString(),
      budgetSectionName: row['budget_section_name'].toString(),
      fundingId: row['funding_id'].toString(),
      fundingReference: row['funding_reference'].toString(),
      title: row['title'].toString(),
      description: row['description']?.toString(),
      beneficiary: row['beneficiary']?.toString(),
      executionNote: row['execution_note']?.toString(),
      requesterDepartment: row['requester_department']?.toString(),
      contactPhone: row['contact_phone']?.toString(),
      reservedAmount: parseDouble(row['reserved_amount']),
      workflowStatus: row['workflow_status'].toString(),
      reservationDate: row['reservation_date'].toString(),
      createdAt: row['created_at'].toString(),
      approvedAt: row['approved_at']?.toString(),
      cancelledAt: row['cancelled_at']?.toString(),
      closedAt: row['closed_at']?.toString(),
      fundingAvailableBalance: parseDouble(row['funding_available_balance']),
      spentAmount: parseDouble(row['spent_amount']),
      remainingAmount: parseDouble(row['remaining_amount']),
      executionStatus: row['execution_status']?.toString() ?? 'not_executed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reservation_number': reservationNumber,
      'program_id': programId,
      'program_code': programCode,
      'program_name': programName,
      'budget_section_id': budgetSectionId,
      'budget_section_code': budgetSectionCode,
      'budget_section_name': budgetSectionName,
      'funding_id': fundingId,
      'funding_reference': fundingReference,
      'title': title,
      'description': description,
      'beneficiary': beneficiary,
      'execution_note': executionNote,
      'requester_department': requesterDepartment,
      'contact_phone': contactPhone,
      'reserved_amount': reservedAmount,
      'workflow_status': workflowStatus,
      'reservation_date': reservationDate,
      'created_at': createdAt,
      'approved_at': approvedAt,
      'cancelled_at': cancelledAt,
      'closed_at': closedAt,
      'funding_available_balance': fundingAvailableBalance,
      'spent_amount': spentAmount,
      'remaining_amount': remainingAmount,
      'execution_status': executionStatus,
    };
  }
}
