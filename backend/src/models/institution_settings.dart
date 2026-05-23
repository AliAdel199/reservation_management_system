import 'dart:convert';

class InstitutionSettings {
  const InstitutionSettings({
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
  final List<Map<String, dynamic>> reportSignatures;
  final String updatedAt;

  factory InstitutionSettings.fromRow(Map<String, dynamic> row) {
    return InstitutionSettings(
      id: row['id'].toString(),
      name: row['name'].toString(),
      ministryName: row['ministry_name']?.toString(),
      departmentName: row['department_name']?.toString(),
      sectionName: row['section_name']?.toString(),
      divisionName: row['division_name']?.toString(),
      address: row['address']?.toString(),
      phone: row['phone']?.toString(),
      email: row['email']?.toString(),
      website: row['website']?.toString(),
      logoPath: row['logo_path']?.toString(),
      documentHeader: row['document_header']?.toString(),
      documentFooter: row['document_footer']?.toString(),
      reportTitle: row['report_title']?.toString(),
      showReportSignatures: row['show_report_signatures'] == true,
      reportSignatures: _parseSignatures(row['report_signatures']),
      updatedAt: row['updated_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'report_signatures': reportSignatures,
      'updated_at': updatedAt,
    };
  }

  static List<Map<String, dynamic>> _parseSignatures(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
