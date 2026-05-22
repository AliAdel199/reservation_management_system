import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/alerts/presentation/pages/balance_alerts_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/audit_logs/presentation/pages/audit_logs_page.dart';
import '../../features/budget_sections/presentation/pages/budget_sections_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/data_exchange/presentation/pages/data_exchange_page.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/fiscal_years/presentation/pages/fiscal_years_page.dart';
import '../../features/fundings/presentation/pages/fundings_page.dart';
import '../../features/institution/presentation/pages/institution_page.dart';
import '../../features/programs/presentation/pages/programs_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reservations/presentation/pages/reservations_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../../layouts/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentLocation: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const BalanceAlertsPage(),
          ),
          GoRoute(
            path: '/programs',
            builder: (context, state) => const ProgramsPage(),
          ),
          GoRoute(
            path: '/fiscal-years',
            builder: (context, state) => const FiscalYearsPage(),
          ),
          GoRoute(
            path: '/budget-types',
            redirect: (context, state) => '/programs',
          ),
          GoRoute(
            path: '/budget-sections',
            builder: (context, state) => const BudgetSectionsPage(),
          ),
          GoRoute(
            path: '/fundings',
            builder: (context, state) => const FundingsPage(),
          ),
          GoRoute(
            path: '/monthly-fundings',
            // تعليق عربي: الشاشة معلّقة مؤقتاً لحين تثبيت مفهوم التمويل الشهري.
            redirect: (context, state) => '/programs',
          ),
          GoRoute(
            path: '/reservations',
            builder: (context, state) => ReservationsPage(
              initialProgramId: state.uri.queryParameters['program_id'],
              initialBudgetSectionId:
                  state.uri.queryParameters['budget_section_id'],
            ),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => ExpensesPage(
              initialReservationId: state.uri.queryParameters['reservation_id'],
              openCreateOnLoad: state.uri.queryParameters['open_create'] == '1',
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/institution',
            builder: (context, state) => const InstitutionPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: '/audit-logs',
            builder: (context, state) => const AuditLogsPage(),
          ),
          GoRoute(
            path: '/data-exchange',
            builder: (context, state) => const DataExchangePage(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = authState.asData?.value != null;
      final isLoading = authState.isLoading;
      final isLoginRoute = location == '/login';
      final isSplashRoute = location == '/splash';

      // تعليق عربي: نمنع التنقل قبل استعادة الجلسة حتى لا يظهر وميض بين الشاشات.
      if (isLoading && !isSplashRoute) {
        return '/splash';
      }

      if (!isLoading && !isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (!isLoading && isAuthenticated && (isLoginRoute || isSplashRoute)) {
        return '/dashboard';
      }

      return null;
    },
  );
});

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
