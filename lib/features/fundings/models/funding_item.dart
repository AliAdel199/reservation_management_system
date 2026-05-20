class FundingItem {
  const FundingItem({
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

  factory FundingItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return FundingItem(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      programCode: json['program_code'] as String,
      programName: json['program_name'] as String,
      budgetSectionId: json['budget_section_id'] as String,
      budgetSectionCode: json['budget_section_code'] as String,
      budgetSectionName: json['budget_section_name'] as String,
      fundingReference: json['funding_reference'] as String,
      fiscalYear: parseInt(json['fiscal_year']),
      allocatedAmount: parseDouble(json['allocated_amount']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
