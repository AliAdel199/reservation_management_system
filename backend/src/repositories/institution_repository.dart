import 'package:postgres/postgres.dart';

import '../models/app_exception.dart';
import '../models/institution_settings.dart';

class InstitutionRepository {
  const InstitutionRepository();

  Future<InstitutionSettings> get(Session session) async {
    final result = await session.execute('''
      SELECT *
      FROM institution_settings
      ORDER BY created_at ASC
      LIMIT 1
    ''');

    if (result.isEmpty) {
      throw const AppException(
        message: 'Institution settings are not initialized.',
        statusCode: 500,
        code: 'INSTITUTION_SETTINGS_MISSING',
      );
    }

    return InstitutionSettings.fromRow(result.first.toColumnMap());
  }

  Future<InstitutionSettings> update({
    required Session session,
    required String id,
    required String name,
    required String? ministryName,
    required String? departmentName,
    required String? address,
    required String? phone,
    required String? email,
    required String? website,
    required String? logoPath,
    required String? documentHeader,
    required String? documentFooter,
    required String updatedBy,
  }) async {
    await session.execute(
      Sql.named('''
        UPDATE institution_settings
        SET
          name = @name,
          ministry_name = @ministry_name,
          department_name = @department_name,
          address = @address,
          phone = @phone,
          email = @email,
          website = @website,
          logo_path = @logo_path,
          document_header = @document_header,
          document_footer = @document_footer,
          updated_by = @updated_by::uuid
        WHERE id = @id::uuid
      '''),
      parameters: {
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
        'updated_by': updatedBy,
      },
    );

    return get(session);
  }
}
