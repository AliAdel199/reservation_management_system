class MonthlyFundingItem {
  const MonthlyFundingItem({
    required this.id,
    required this.fiscalYearId,
    required this.fiscalYear,
    required this.budgetTypeId,
    required this.budgetTypeName,
    required this.programId,
    required this.programName,
    required this.sectionId,
    required this.sectionName,
    required this.month,
    required this.amount,
    required this.reservedAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.fundingDate,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String fiscalYearId;
  final int fiscalYear;
  final String budgetTypeId;
  final String budgetTypeName;
  final String programId;
  final String programName;
  final String? sectionId;
  final String sectionName;
  final int month;
  final double amount;
  final double reservedAmount;
  final double spentAmount;
  final double remainingAmount;
  final String fundingDate;
  final String? notes;
  final String createdAt;

  factory MonthlyFundingItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return MonthlyFundingItem(
      id: json['id'] as String,
      fiscalYearId: json['fiscal_year_id'] as String,
      fiscalYear: parseInt(json['fiscal_year']),
      budgetTypeId: json['budget_type_id'] as String,
      budgetTypeName: json['budget_type_name'] as String,
      programId: json['program_id'] as String,
      programName: json['program_name'] as String,
      sectionId: json['section_id']?.toString(),
      sectionName:
          json['section_name']?.toString() ?? 'تمويل عام على مستوى البرنامج',
      month: parseInt(json['month']),
      amount: parseDouble(json['amount']),
      reservedAmount: parseDouble(json['reserved_amount']),
      spentAmount: parseDouble(json['spent_amount']),
      remainingAmount: parseDouble(json['remaining_amount']),
      fundingDate: json['funding_date']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
