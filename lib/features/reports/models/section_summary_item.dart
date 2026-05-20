class SectionSummaryItem {
  const SectionSummaryItem({
    required this.sectionCode,
    required this.sectionName,
    required this.programCode,
    required this.programName,
    required this.fiscalYearName,
    required this.budgetTypeName,
    required this.allocatedAmount,
    required this.totalFunding,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingAllocation,
    required this.remainingBySpent,
    required this.monthlyQuota,
    required this.allowedMonths,
    required this.periodAllowedAmount,
    required this.periodDisposableAmount,
    required this.remainingFunding,
    required this.disposableAmount,
    required this.reservationRate,
    required this.spendingRate,
  });

  final String sectionCode;
  final String sectionName;
  final String programCode;
  final String programName;
  final String? fiscalYearName;
  final String? budgetTypeName;
  final double allocatedAmount;
  final double totalFunding;
  final double totalReserved;
  final double totalSpent;
  final double remainingAllocation;
  final double remainingBySpent;
  final double monthlyQuota;
  final int allowedMonths;
  final double periodAllowedAmount;
  final double periodDisposableAmount;
  final double remainingFunding;
  final double disposableAmount;
  final double reservationRate;
  final double spendingRate;

  double effectiveRemainingBySpent() {
    return remainingBySpent != 0
        ? remainingBySpent
        : allocatedAmount - totalSpent;
  }

  double effectiveMonthlyQuota() {
    return monthlyQuota != 0 ? monthlyQuota : allocatedAmount / 12;
  }

  double effectivePeriodAllowed(int month) {
    return periodAllowedAmount != 0
        ? periodAllowedAmount
        : effectiveMonthlyQuota() * month;
  }

  double effectivePeriodDisposable(int month) {
    return periodDisposableAmount != 0
        ? periodDisposableAmount
        : effectivePeriodAllowed(month) - totalReserved;
  }

  factory SectionSummaryItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return SectionSummaryItem(
      sectionCode: json['section_code']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      programCode: json['program_code']?.toString() ?? '',
      programName: json['program_name']?.toString() ?? '',
      fiscalYearName: json['fiscal_year_name']?.toString(),
      budgetTypeName: json['budget_type_name']?.toString(),
      allocatedAmount: parseDouble(json['allocated_amount']),
      totalFunding: parseDouble(json['total_funding']),
      totalReserved: parseDouble(json['total_reserved']),
      totalSpent: parseDouble(json['total_spent']),
      remainingAllocation: parseDouble(json['remaining_allocation']),
      remainingBySpent: parseDouble(json['remaining_by_spent']),
      monthlyQuota: parseDouble(json['monthly_quota']),
      allowedMonths:
          int.tryParse(json['allowed_months']?.toString() ?? '0') ?? 0,
      periodAllowedAmount: parseDouble(json['period_allowed_amount']),
      periodDisposableAmount: parseDouble(json['period_disposable_amount']),
      remainingFunding: parseDouble(json['remaining_funding']),
      disposableAmount: parseDouble(json['disposable_amount']),
      reservationRate: parseDouble(json['reservation_rate']),
      spendingRate: parseDouble(json['spending_rate']),
    );
  }
}
