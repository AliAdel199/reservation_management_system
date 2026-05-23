class InstitutionSettingsItem {
  const InstitutionSettingsItem({
    required this.id,
    required this.name,
    required this.ministryName,
    required this.departmentName,
    required this.sectionName,
    required this.divisionName,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.logoPath,
    required this.documentHeader,
    required this.documentFooter,
    required this.reportTitle,
    required this.showReportSignatures,
    required this.reportSignatures,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? ministryName;
  final String? departmentName;
  final String? sectionName;
  final String? divisionName;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoPath;
  final String? documentHeader;
  final String? documentFooter;
  final String? reportTitle;
  final bool showReportSignatures;
  final List<ReportSignatureItem> reportSignatures;
  final String updatedAt;

  factory InstitutionSettingsItem.fromJson(Map<String, dynamic> json) {
    return InstitutionSettingsItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ministryName: json['ministry_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      sectionName: json['section_name']?.toString(),
      divisionName: json['division_name']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      logoPath: json['logo_path']?.toString(),
      documentHeader: json['document_header']?.toString(),
      documentFooter: json['document_footer']?.toString(),
      reportTitle: json['report_title']?.toString(),
      showReportSignatures: json['show_report_signatures'] == true,
      reportSignatures: _parseSignatures(json['report_signatures']),
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'name': name,
      'ministry_name': ministryName,
      'department_name': departmentName,
      'section_name': sectionName,
      'division_name': divisionName,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logo_path': logoPath,
      'document_header': documentHeader,
      'document_footer': documentFooter,
      'report_title': reportTitle,
      'show_report_signatures': showReportSignatures,
      'report_signatures': reportSignatures
          .map((signature) => signature.toJson())
          .toList(),
    };
  }

  static List<ReportSignatureItem> _parseSignatures(dynamic value) {
    if (value is! List) return const <ReportSignatureItem>[];
    return value
        .whereType<Map>()
        .map((item) => ReportSignatureItem.fromJson(item))
        .where((item) => item.hasValue)
        .take(5)
        .toList();
  }
}

class ReportSignatureItem {
  const ReportSignatureItem({
    required this.title,
    required this.name,
    required this.location,
  });

  final String? title;
  final String? name;
  final String? location;

  bool get hasValue =>
      (title?.trim().isNotEmpty ?? false) ||
      (name?.trim().isNotEmpty ?? false) ||
      (location?.trim().isNotEmpty ?? false);

  factory ReportSignatureItem.fromJson(Map<dynamic, dynamic> json) {
    return ReportSignatureItem(
      title: json['title']?.toString(),
      name: json['name']?.toString(),
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'name': name, 'location': location};
  }
}
