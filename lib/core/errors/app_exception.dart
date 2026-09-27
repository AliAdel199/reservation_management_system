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

    // تعليق عربي: رسائل Dio الافتراضية إنجليزية وتقنية، لذلك نعرض سبباً مفهوماً للمستخدم.
    return AppException(
      message: _connectionMessage(exception),
      statusCode: exception.response?.statusCode,
    );
  }

  static String _connectionMessage(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'انتهت مهلة الاتصال بالخادم. تحقق من الشبكة وحاول مرة أخرى.',
      DioExceptionType.connectionError =>
        'تعذر الاتصال بالخادم. تأكد من تشغيل الخادم وصحة عنوانه في إعدادات الاتصال.',
      DioExceptionType.badCertificate => 'شهادة أمان الخادم غير موثوقة.',
      DioExceptionType.cancel => 'تم إلغاء الطلب.',
      DioExceptionType.badResponse =>
        'تعذر تنفيذ الطلب (رمز ${exception.response?.statusCode ?? '-'}). تأكد من عنوان الخادم.',
      DioExceptionType.unknown => 'تعذر الاتصال بالخادم.',
    };
  }

  @override
  String toString() => message;
}
