class AppConstants {
  const AppConstants._();

  static const appName = 'نظام إدارة الحجوزات المالية';
  static const copyrightNotice =
      '© 2026 Ali Adel (DuraTec). All rights reserved.';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:7171/api',
  );
}
