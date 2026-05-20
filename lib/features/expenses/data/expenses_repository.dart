import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/paged_result.dart';
import '../models/expense_item.dart';

class ExpensesRepository {
  const ExpensesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PagedResult<ExpenseItem>> fetchExpenses({
    required String search,
    required String? reservationId,
    required String? programId,
    required String? budgetSectionId,
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _apiClient.instance.get<Map<String, dynamic>>(
        '/expenses',
        queryParameters: {
          'search': search,
          'reservation_id': reservationId,
          'program_id': programId,
          'budget_section_id': budgetSectionId,
          'page': page,
          'page_size': pageSize,
        },
      );

      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic>) {
        throw const AppException(
          message: 'تعذر قراءة قائمة الصرف من الخادم.',
          code: 'INVALID_EXPENSES_RESPONSE',
        );
      }

      return PagedResult<ExpenseItem>.fromJson(payload, ExpenseItem.fromJson);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> createExpense(Map<String, dynamic> payload) async {
    try {
      await _apiClient.instance.post('/expenses', data: payload);
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }

  Future<void> cancelExpense({
    required String id,
    required String reason,
  }) async {
    try {
      await _apiClient.instance.patch(
        '/expenses/$id/cancel',
        data: {'cancel_reason': reason},
      );
    } on DioException catch (exception) {
      throw AppException.fromDioException(exception);
    }
  }
}
