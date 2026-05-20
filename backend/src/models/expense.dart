class Expense {
  const Expense({
    required this.id,
    required this.reservationId,
    required this.reservationNumber,
    required this.programName,
    required this.budgetSectionName,
    required this.expenseNumber,
    required this.amount,
    required this.expenseStatus,
    required this.expenseDate,
    required this.paymentMethod,
    required this.documentNumber,
    required this.documentDate,
    required this.description,
    required this.createdAt,
    required this.cancelledAt,
    required this.cancelReason,
  });

  final String id;
  final String reservationId;
  final String reservationNumber;
  final String programName;
  final String budgetSectionName;
  final String expenseNumber;
  final double amount;
  final String expenseStatus;
  final String expenseDate;
  final String? paymentMethod;
  final String? documentNumber;
  final String? documentDate;
  final String? description;
  final String createdAt;
  final String? cancelledAt;
  final String? cancelReason;

  factory Expense.fromRow(Map<String, dynamic> row) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return Expense(
      id: row['id'].toString(),
      reservationId: row['reservation_id'].toString(),
      reservationNumber: row['reservation_number'].toString(),
      programName: row['program_name'].toString(),
      budgetSectionName: row['budget_section_name'].toString(),
      expenseNumber: row['expense_number'].toString(),
      amount: parseDouble(row['amount']),
      expenseStatus: row['expense_status'].toString(),
      expenseDate: row['expense_date'].toString(),
      paymentMethod: row['payment_method']?.toString(),
      documentNumber: row['document_number']?.toString(),
      documentDate: row['document_date']?.toString(),
      description: row['description']?.toString(),
      createdAt: row['created_at'].toString(),
      cancelledAt: row['cancelled_at']?.toString(),
      cancelReason: row['cancel_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reservation_id': reservationId,
      'reservation_number': reservationNumber,
      'program_name': programName,
      'budget_section_name': budgetSectionName,
      'expense_number': expenseNumber,
      'amount': amount,
      'expense_status': expenseStatus,
      'expense_date': expenseDate,
      'payment_method': paymentMethod,
      'document_number': documentNumber,
      'document_date': documentDate,
      'description': description,
      'created_at': createdAt,
      'cancelled_at': cancelledAt,
      'cancel_reason': cancelReason,
    };
  }
}
