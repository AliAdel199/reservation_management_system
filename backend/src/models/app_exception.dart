class AppException implements Exception {
  const AppException({
    required this.message,
    this.statusCode = 400,
    this.code = 'APP_ERROR',
    this.details,
  });

  final String message;
  final int statusCode;
  final String code;
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}
