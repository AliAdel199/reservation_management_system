class FundingMovementItem {
  const FundingMovementItem({
    required this.id,
    required this.transactionNumber,
    required this.transactionType,
    required this.amount,
    required this.transactionDate,
    required this.description,
    required this.programName,
    required this.budgetSectionCode,
    required this.budgetSectionName,
    required this.createdByName,
  });

  final String id;
  final String transactionNumber;
  final String transactionType;
  final double amount;
  final String transactionDate;
  final String? description;
  final String? programName;
  final String? budgetSectionCode;
  final String? budgetSectionName;
  final String? createdByName;

  factory FundingMovementItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return FundingMovementItem(
      id: json['id']?.toString() ?? '',
      transactionNumber: json['transaction_number']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      amount: parseDouble(json['amount']),
      transactionDate: json['transaction_date']?.toString() ?? '',
      description: json['description']?.toString(),
      programName: json['program_name']?.toString(),
      budgetSectionCode: json['budget_section_code']?.toString(),
      budgetSectionName: json['budget_section_name']?.toString(),
      createdByName: json['created_by_name']?.toString(),
    );
  }

  String get typeLabel {
    switch (transactionType) {
      case 'allocation':
        return 'إضافة تخصيص';
      case 'allocation_reversal':
        return 'عكس تخصيص';
      case 'adjustment_increase':
        return 'زيادة تخصيص';
      case 'adjustment_decrease':
        return 'نقص تخصيص';
      default:
        return transactionType;
    }
  }
}
