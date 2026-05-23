class DashboardSummary {
  const DashboardSummary({
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.disposableBalance,
    required this.reservationRate,
    required this.spendingRate,
    required this.noMovementSectionsCount,
    this.balanceAlerts = const [],
  });

  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final double disposableBalance;
  final double reservationRate;
  final double spendingRate;
  final int noMovementSectionsCount;
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
      'no_movement_sections_count': noMovementSectionsCount,
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

class DashboardSectionCard {
  const DashboardSectionCard({
    required this.sectionId,
    required this.programId,
    required this.programName,
    required this.sectionCode,
    required this.sectionName,
    required this.sectionPath,
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.childrenCount,
    required this.postableChildrenCount,
  });

  final String sectionId;
  final String programId;
  final String programName;
  final String sectionCode;
  final String sectionName;
  final String sectionPath;
  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final int childrenCount;
  final int postableChildrenCount;

  Map<String, dynamic> toJson() {
    return {
      'section_id': sectionId,
      'program_id': programId,
      'program_name': programName,
      'section_code': sectionCode,
      'section_name': sectionName,
      'section_path': sectionPath,
      'total_allocation': totalAllocation,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
      'remaining_balance': remainingBalance,
      'children_count': childrenCount,
      'postable_children_count': postableChildrenCount,
    };
  }
}
