class Funding {
  const Funding({
    required this.id,
    required this.programId,
    required this.programCode,
    required this.programName,
    required this.budgetSectionId,
    required this.budgetSectionCode,
    required this.budgetSectionName,
    required this.fundingReference,
    required this.fiscalYear,
    required this.allocatedAmount,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String programId;
  final String programCode;
  final String programName;
  final String budgetSectionId;
  final String budgetSectionCode;
  final String budgetSectionName;
  final String fundingReference;
  final int fiscalYear;
  final double allocatedAmount;
  final String? notes;
  final String createdAt;

  factory Funding.fromRow(Map<String, dynamic> row) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return Funding(
      id: row['id'].toString(),
      programId: row['program_id'].toString(),
      programCode: row['program_code'].toString(),
      programName: row['program_name'].toString(),
      budgetSectionId: row['budget_section_id'].toString(),
      budgetSectionCode: row['budget_section_code'].toString(),
      budgetSectionName: row['budget_section_name'].toString(),
      fundingReference: row['funding_reference'].toString(),
      fiscalYear: parseInt(row['fiscal_year']),
      allocatedAmount: parseDouble(row['allocated_amount']),
      notes: row['notes']?.toString(),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'program_id': programId,
      'program_code': programCode,
      'program_name': programName,
      'budget_section_id': budgetSectionId,
      'budget_section_code': budgetSectionCode,
      'budget_section_name': budgetSectionName,
      'funding_reference': fundingReference,
      'fiscal_year': fiscalYear,
      'allocated_amount': allocatedAmount,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
