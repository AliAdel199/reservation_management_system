class BudgetType {
  const BudgetType({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final String createdAt;

  factory BudgetType.fromRow(Map<String, dynamic> row) {
    return BudgetType(
      id: row['id'].toString(),
      code: row['code'].toString(),
      name: row['name'].toString(),
      description: row['description']?.toString(),
      isActive: row['is_active'] == true,
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}
