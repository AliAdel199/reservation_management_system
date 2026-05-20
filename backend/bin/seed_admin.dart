import '../src/config/app_config.dart';
import '../src/config/logger_config.dart';
import '../src/database/database_seeder.dart';
import '../src/database/database_service.dart';
import '../src/repositories/auth_repository.dart';
import '../src/services/audit_service.dart';
import '../src/services/password_service.dart';

Future<void> main() async {
  final config = AppConfig.fromEnvironment();
  final logger = configureLogging();
  final database = DatabaseService(config: config, logger: logger);

  await database.connect();

  final seeder = DatabaseSeeder(
    config: config,
    database: database,
    authRepository: AuthRepository(),
    passwordService: PasswordService(),
    auditService: AuditService(),
    logger: logger,
  );

  await seeder.seedFoundation();
  await database.close();
}
