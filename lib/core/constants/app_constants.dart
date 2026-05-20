class AppConstants {
  const AppConstants._();

  static const appName = 'نظام إدارة الحجوزات المالية';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:7070/api',
  );
}
