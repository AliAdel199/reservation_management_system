import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  factory AppException.fromDioException(DioException exception) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      return AppException(
        message: responseData['message']?.toString() ?? 'حدث خطأ غير متوقع',
        statusCode: exception.response?.statusCode,
        code: responseData['code']?.toString(),
      );
    }

    return AppException(
      message: exception.message ?? 'تعذر الاتصال بالخادم',
      statusCode: exception.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
