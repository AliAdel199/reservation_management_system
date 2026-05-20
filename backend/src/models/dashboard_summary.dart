class DashboardSummary {
  const DashboardSummary({
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.disposableBalance,
    required this.reservationRate,
    required this.spendingRate,
    this.balanceAlerts = const [],
  });

  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final double disposableBalance;
  final double reservationRate;
  final double spendingRate;
  final List<DashboardBalanceAlert> balanceAlerts;

  Map<String, dynamic> toJson() {
    return {
      'total_allocation': totalAllocation,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
      'remaining_balance': remainingBalance,
      'disposable_balance': disposableBalance,
      'reservation_rate': reservationRate,
      'spending_rate': spendingRate,
      'balance_alerts': balanceAlerts.map((alert) => alert.toJson()).toList(),
    };
  }
}

class DashboardBalanceAlert {
  const DashboardBalanceAlert({
    required this.programName,
    required this.sectionCode,
    required this.sectionName,
    required this.remainingFunding,
    required this.threshold,
    required this.severity,
    required this.message,
  });

  final String programName;
  final String sectionCode;
  final String sectionName;
  final double remainingFunding;
  final double threshold;
  final String severity;
  final String message;

  Map<String, dynamic> toJson() {
    return {
      'program_name': programName,
      'section_code': sectionCode,
      'section_name': sectionName,
      'remaining_funding': remainingFunding,
      'threshold': threshold,
      'severity': severity,
      'message': message,
    };
  }
}
