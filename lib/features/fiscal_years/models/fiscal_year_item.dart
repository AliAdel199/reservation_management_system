class FiscalYearItem {
  const FiscalYearItem({
    required this.id,
    required this.year,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final int year;
  final String name;
  final String startDate;
  final String endDate;
  final bool isActive;
  final String createdAt;

  factory FiscalYearItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return FiscalYearItem(
      id: json['id'] as String,
      year: parseInt(json['year']),
      name: json['name'] as String,
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
