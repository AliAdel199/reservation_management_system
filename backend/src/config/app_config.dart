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
    required this.licenseEnforcementEnabled,
    required this.licenseFilePath,
    required this.licensePublicKeyPath,
    required this.backupDirectory,
    required this.pgDumpPath,
    required this.pgRestorePath,
    required this.backupRetentionDays,
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
  final bool licenseEnforcementEnabled;
  final String licenseFilePath;
  final String licensePublicKeyPath;
  final String backupDirectory;
  final String pgDumpPath;
  final String pgRestorePath;
  final int backupRetentionDays;

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
      licenseEnforcementEnabled:
          const bool.fromEnvironment('LICENSE_REQUIRED') ||
          (env['LICENSE_ENFORCEMENT'] ?? 'false').toLowerCase() == 'true',
      licenseFilePath: env['LICENSE_FILE'] ?? 'license.json',
      licensePublicKeyPath: env['LICENSE_PUBLIC_KEY'] ?? 'license_public.pem',
      backupDirectory: env['BACKUP_DIR'] ?? 'backups',
      pgDumpPath: env['PG_DUMP_PATH'] ?? 'pg_dump',
      pgRestorePath: env['PG_RESTORE_PATH'] ?? 'pg_restore',
      backupRetentionDays:
          int.tryParse(env['BACKUP_RETENTION_DAYS'] ?? '30') ?? 30,
    );
  }
}
