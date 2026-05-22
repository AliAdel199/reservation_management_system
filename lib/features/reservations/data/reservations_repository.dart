import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/reservation_item.dart';

class ReservationsRepository {
  const ReservationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<ReservationItem>> fetchReservations({
    required String search,
    required String? status,
    required String? programId,
    required String? budgetSectionId,
    required String? fundingId,
    required String? executionStatus,
    required String? dateFrom,
    required String? dateTo,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/reservations',
        queryParameters: {
          'search': search,
          'status': status,
          'program_id': programId,
          'budget_section_id': budgetSectionId,
          'funding_id': fundingId,
          'execution_status': executionStatus,
          'date_from': dateFrom,
          'date_to': dateTo,
          'page': page,
          'page_size': pageSize,
        },
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة الحجوزات من الخادم.',
          code: 'INVALID_RESERVATIONS_RESPONSE',
        );
      }

      return PagedResult<ReservationItem>.fromJson(
        payload,
        ReservationItem.fromJson,
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<ReservationItem> createReservation(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _apiClient.instance.post<Map<String, dynamic>>(
        '/reservations',
        data: payload,
      );
      final payloadData = response.data?['data'];
      if (payloadData is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة الحجز المنشأ من الخادم.',
          code: 'INVALID_CREATED_RESERVATION_RESPONSE',
        );
      }
      return ReservationItem.fromJson(payloadData);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> updateReservation({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.instance.put('/reservations/$id', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> submitForReview(String id) async {
    try {
      await _apiClient.instance.post('/reservations/$id/submit-review');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> approve(String id) async {
    try {
      await _apiClient.instance.post('/reservations/$id/approve');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _apiClient.instance.post('/reservations/$id/cancel');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> deleteReservation(String id) async {
    try {
      await _apiClient.instance.delete('/reservations/$id');
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
