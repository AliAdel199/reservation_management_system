import 'package:dotenv/dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.host,
    required this.port,
    required this.databaseUrl,
    required this.jwtSecret,
    required this.jwtExpiresInHours,
    required this.defaultAdminUsername,
    required this.defaultAdminPassword,
    required this.defaultAdminFullName,
    required this.defaultAdminEmail,
  });

  final String appName;
  final String host;
  final int port;
  final String databaseUrl;
  final String jwtSecret;
  final int jwtExpiresInHours;
  final String defaultAdminUsername;
  final String defaultAdminPassword;
  final String defaultAdminFullName;
  final String defaultAdminEmail;

  factory AppConfig.fromEnvironment() {
    final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();

    return AppConfig(
      appName: env['APP_NAME'] ?? 'Government Reservation API',
      host: env['HOST'] ?? '0.0.0.0',
      port: int.tryParse(env['PORT'] ?? '8080') ?? 8080,
      databaseUrl:
          env['DATABASE_URL'] ??
          'postgresql://postgres:postgres@localhost:5432/reservation_management?sslmode=disable',
      jwtSecret: env['JWT_SECRET'] ?? 'change-this-secret-before-production',
      jwtExpiresInHours: int.tryParse(env['JWT_EXPIRES_IN_HOURS'] ?? '8') ?? 8,
      defaultAdminUsername: env['DEFAULT_ADMIN_USERNAME'] ?? 'admin',
      defaultAdminPassword: env['DEFAULT_ADMIN_PASSWORD'] ?? 'Admin@123',
      defaultAdminFullName:
          env['DEFAULT_ADMIN_FULL_NAME'] ?? 'System Administrator',
      defaultAdminEmail: env['DEFAULT_ADMIN_EMAIL'] ?? 'admin@finance.local',
    );
  }
}
