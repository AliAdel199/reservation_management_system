class MonthlyFunding {
  const MonthlyFunding({
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

  factory MonthlyFunding.fromRow(Map<String, dynamic> row) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return MonthlyFunding(
      id: row['id'].toString(),
      fiscalYearId: row['fiscal_year_id'].toString(),
      fiscalYear: parseInt(row['fiscal_year']),
      budgetTypeId: row['budget_type_id'].toString(),
      budgetTypeName: row['budget_type_name'].toString(),
      programId: row['program_id'].toString(),
      programName: row['program_name'].toString(),
      sectionId: row['section_id']?.toString(),
      sectionName:
          row['section_name']?.toString() ?? 'تمويل عام على مستوى البرنامج',
      month: parseInt(row['month']),
      amount: parseDouble(row['amount']),
      reservedAmount: parseDouble(row['reserved_amount']),
      spentAmount: parseDouble(row['spent_amount']),
      remainingAmount: parseDouble(row['remaining_amount']),
      fundingDate: row['funding_date'].toString(),
      notes: row['notes']?.toString(),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fiscal_year_id': fiscalYearId,
      'fiscal_year': fiscalYear,
      'budget_type_id': budgetTypeId,
      'budget_type_name': budgetTypeName,
      'program_id': programId,
      'program_name': programName,
      'section_id': sectionId,
      'section_name': sectionName,
      'month': month,
      'amount': amount,
      'reserved_amount': reservedAmount,
      'spent_amount': spentAmount,
      'remaining_amount': remainingAmount,
      'funding_date': fundingDate,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
