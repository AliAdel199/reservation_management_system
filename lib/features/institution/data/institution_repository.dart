import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/institution_settings_item.dart';

class InstitutionRepository {
  const InstitutionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<InstitutionSettingsItem> fetchSettings() async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/institution',
      );
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة معلومات المؤسسة.',
          code: 'INVALID_INSTITUTION_RESPONSE',
        );
      }
      return InstitutionSettingsItem.fromJson(payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<InstitutionSettingsItem> updateSettings(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _apiClient.instance.put<Map<String, dynamic>>(
        '/institution',
        data: payload,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر حفظ معلومات المؤسسة.',
          code: 'INVALID_INSTITUTION_SAVE_RESPONSE',
        );
      }
      return InstitutionSettingsItem.fromJson(data);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
