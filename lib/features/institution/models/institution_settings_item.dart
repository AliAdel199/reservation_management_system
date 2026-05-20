class InstitutionSettingsItem {
  const InstitutionSettingsItem({
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

  factory InstitutionSettingsItem.fromJson(Map<String, dynamic> json) {
    return InstitutionSettingsItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ministryName: json['ministry_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      logoPath: json['logo_path']?.toString(),
      documentHeader: json['document_header']?.toString(),
      documentFooter: json['document_footer']?.toString(),
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() {
    return {
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
    };
  }
}
