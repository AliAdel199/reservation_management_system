class InstitutionSettings {
  const InstitutionSettings({
    required this.id,
    required this.name,
    required this.ministryName,
    required this.departmentName,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.logoPath,
    required this.documentHeader,
    required this.documentFooter,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? ministryName;
  final String? departmentName;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoPath;
  final String? documentHeader;
  final String? documentFooter;
  final String updatedAt;

  factory InstitutionSettings.fromRow(Map<String, dynamic> row) {
    return InstitutionSettings(
      id: row['id'].toString(),
      name: row['name'].toString(),
      ministryName: row['ministry_name']?.toString(),
      departmentName: row['department_name']?.toString(),
      address: row['address']?.toString(),
      phone: row['phone']?.toString(),
      email: row['email']?.toString(),
      website: row['website']?.toString(),
      logoPath: row['logo_path']?.toString(),
      documentHeader: row['document_header']?.toString(),
      documentFooter: row['document_footer']?.toString(),
      updatedAt: row['updated_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ministry_name': ministryName,
      'department_name': departmentName,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logo_path': logoPath,
      'document_header': documentHeader,
      'document_footer': documentFooter,
      'updated_at': updatedAt,
    };
  }
}
