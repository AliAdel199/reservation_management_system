import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/audit_logs_controller.dart';
import '../controllers/backups_controller.dart';
import '../controllers/budget_sections_controller.dart';
import '../controllers/budget_types_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/expenses_controller.dart';
import '../controllers/fiscal_years_controller.dart';
import '../controllers/fundings_controller.dart';
import '../controllers/health_controller.dart';
import '../controllers/institution_controller.dart';
import '../controllers/license_controller.dart';
import '../controllers/monthly_fundings_controller.dart';
import '../controllers/programs_controller.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reservations_controller.dart';
import '../controllers/users_controller.dart';
import '../services/jwt_service.dart';
import 'audit_logs_routes.dart';
import 'auth_routes.dart';
import 'backups_routes.dart';
import 'budget_sections_routes.dart';
import 'budget_types_routes.dart';
import 'dashboard_routes.dart';
import 'expenses_routes.dart';
import 'fiscal_years_routes.dart';
import 'fundings_routes.dart';
import 'health_routes.dart';
import 'institution_routes.dart';
import 'license_routes.dart';
import 'programs_routes.dart';
import 'reports_routes.dart';
import 'reservations_routes.dart';
import 'users_routes.dart';

Handler buildAppRouter({
  required HealthController healthController,
  required AuthController authController,
  required InstitutionController institutionController,
  required LicenseController licenseController,
  required UsersController usersController,
  required AuditLogsController auditLogsController,
  required BackupsController backupsController,
  required DashboardController dashboardController,
  required FiscalYearsController fiscalYearsController,
  required BudgetTypesController budgetTypesController,
  required MonthlyFundingsController monthlyFundingsController,
  required FundingsController fundingsController,
  required ProgramsController programsController,
  required ReservationsController reservationsController,
  required ExpensesController expensesController,
  required ReportsController reportsController,
  required BudgetSectionsController budgetSectionsController,
  required JwtService jwtService,
}) {
  final router = Router();

  registerHealthRoutes(router, healthController);
  registerLicenseRoutes(router, licenseController);
  registerAuthRoutes(router, authController, jwtService);
  registerInstitutionRoutes(router, institutionController, jwtService);
  registerUsersRoutes(router, usersController, jwtService);
  registerAuditLogsRoutes(router, auditLogsController, jwtService);
  registerBackupsRoutes(router, backupsController, jwtService);
  registerDashboardRoutes(router, dashboardController, jwtService);
  registerFiscalYearsRoutes(router, fiscalYearsController, jwtService);
  registerBudgetTypesRoutes(router, budgetTypesController, jwtService);
  // تعليق عربي: تم تعليق API التمويل الشهري مؤقتاً حتى تثبت فكرته المحاسبية.
  // نبقي الـ controller موجوداً حتى لا نحذف الميزة جذرياً ويمكن إرجاعها لاحقاً.
  registerFundingsRoutes(router, fundingsController, jwtService);
  registerProgramsRoutes(router, programsController, jwtService);
  registerBudgetSectionsRoutes(router, budgetSectionsController, jwtService);
  registerReservationsRoutes(router, reservationsController, jwtService);
  registerExpensesRoutes(router, expensesController, jwtService);
  registerReportsRoutes(router, reportsController, jwtService);

  return router.call;
}
