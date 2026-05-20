import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'config/app_config.dart';
import 'config/logger_config.dart';
import 'controllers/auth_controller.dart';
import 'controllers/audit_logs_controller.dart';
import 'controllers/budget_sections_controller.dart';
import 'controllers/budget_types_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/expenses_controller.dart';
import 'controllers/fiscal_years_controller.dart';
import 'controllers/fundings_controller.dart';
import 'controllers/health_controller.dart';
import 'controllers/institution_controller.dart';
import 'controllers/monthly_fundings_controller.dart';
import 'controllers/programs_controller.dart';
import 'controllers/reports_controller.dart';
import 'controllers/reservations_controller.dart';
import 'controllers/users_controller.dart';
import 'database/database_seeder.dart';
import 'database/database_service.dart';
import 'repositories/auth_repository.dart';
import 'repositories/audit_logs_repository.dart';
import 'repositories/budget_sections_repository.dart';
import 'repositories/budget_types_repository.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/expenses_repository.dart';
import 'repositories/fiscal_years_repository.dart';
import 'repositories/fundings_repository.dart';
import 'repositories/institution_repository.dart';
import 'repositories/monthly_fundings_repository.dart';
import 'repositories/programs_repository.dart';
import 'repositories/reports_repository.dart';
import 'repositories/reservations_repository.dart';
import 'repositories/users_repository.dart';
import 'routes/app_router.dart';
import 'services/audit_service.dart';
import 'services/jwt_service.dart';
import 'services/password_service.dart';
import 'middlewares/database_keep_alive_middleware.dart';
import 'middlewares/error_middleware.dart';
import 'middlewares/security_headers_middleware.dart';

Future<void> startServer() async {
  final config = AppConfig.fromEnvironment();
  final logger = configureLogging();
  final database = DatabaseService(config: config, logger: logger);

  await database.connect();

  final authRepository = AuthRepository();
  final institutionRepository = InstitutionRepository();
  final usersRepository = UsersRepository();
  final auditLogsRepository = AuditLogsRepository();
  final dashboardRepository = DashboardRepository();
  final fiscalYearsRepository = FiscalYearsRepository();
  final budgetTypesRepository = BudgetTypesRepository();
  final monthlyFundingsRepository = MonthlyFundingsRepository();
  final fundingsRepository = FundingsRepository();
  final programsRepository = ProgramsRepository();
  final reservationsRepository = ReservationsRepository();
  final expensesRepository = ExpensesRepository();
  final reportsRepository = ReportsRepository();
  final budgetSectionsRepository = BudgetSectionsRepository();
  final passwordService = PasswordService();
  final jwtService = JwtService(config);
  final auditService = AuditService();

  final seeder = DatabaseSeeder(
    config: config,
    database: database,
    authRepository: authRepository,
    passwordService: passwordService,
    auditService: auditService,
    logger: logger,
  );
  await seeder.seedFoundation();

  final handler = Pipeline()
      .addMiddleware(
        logRequests(
          logger: (message, isError) {
            final methodLogger = Logger('http');
            if (isError) {
              methodLogger.warning(message);
            } else {
              methodLogger.info(message);
            }
          },
        ),
      )
      .addMiddleware(corsHeaders())
      .addMiddleware(errorMiddleware(logger))
      .addMiddleware(databaseKeepAliveMiddleware(database, logger))
      .addMiddleware(securityHeadersMiddleware())
      .addHandler(
        buildAppRouter(
          healthController: HealthController(database: database),
          authController: AuthController(
            database: database,
            authRepository: authRepository,
            passwordService: passwordService,
            jwtService: jwtService,
            auditService: auditService,
          ),
          institutionController: InstitutionController(
            database: database,
            institutionRepository: institutionRepository,
            auditService: auditService,
          ),
          usersController: UsersController(
            database: database,
            usersRepository: usersRepository,
            passwordService: passwordService,
            auditService: auditService,
          ),
          auditLogsController: AuditLogsController(
            database: database,
            auditLogsRepository: auditLogsRepository,
          ),
          dashboardController: DashboardController(
            database: database,
            dashboardRepository: dashboardRepository,
          ),
          fiscalYearsController: FiscalYearsController(
            database: database,
            fiscalYearsRepository: fiscalYearsRepository,
            auditService: auditService,
          ),
          budgetTypesController: BudgetTypesController(
            database: database,
            budgetTypesRepository: budgetTypesRepository,
            auditService: auditService,
          ),
          monthlyFundingsController: MonthlyFundingsController(
            database: database,
            monthlyFundingsRepository: monthlyFundingsRepository,
            auditService: auditService,
          ),
          fundingsController: FundingsController(
            database: database,
            fundingsRepository: fundingsRepository,
            programsRepository: programsRepository,
            budgetSectionsRepository: budgetSectionsRepository,
            auditService: auditService,
          ),
          programsController: ProgramsController(
            database: database,
            programsRepository: programsRepository,
            auditService: auditService,
          ),
          reservationsController: ReservationsController(
            database: database,
            reservationsRepository: reservationsRepository,
            programsRepository: programsRepository,
            budgetSectionsRepository: budgetSectionsRepository,
            fundingsRepository: fundingsRepository,
            auditService: auditService,
          ),
          expensesController: ExpensesController(
            database: database,
            expensesRepository: expensesRepository,
            auditService: auditService,
          ),
          reportsController: ReportsController(
            database: database,
            reportsRepository: reportsRepository,
          ),
          budgetSectionsController: BudgetSectionsController(
            database: database,
            budgetSectionsRepository: budgetSectionsRepository,
            programsRepository: programsRepository,
            auditService: auditService,
          ),
          jwtService: jwtService,
        ),
      );

  final server = await shelf_io.serve(handler, config.host, config.port);
  logger.info('Server started at http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    logger.info('Shutdown signal received.');
    await server.close(force: true);
    await database.close();
    exit(0);
  });
}
