class FiscalYear {
  const FiscalYear({
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

  factory FiscalYear.fromRow(Map<String, dynamic> row) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return FiscalYear(
      id: row['id'].toString(),
      year: parseInt(row['year']),
      name: row['name'].toString(),
      startDate: row['start_date'].toString(),
      endDate: row['end_date'].toString(),
      isActive: row['is_active'] == true,
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}
