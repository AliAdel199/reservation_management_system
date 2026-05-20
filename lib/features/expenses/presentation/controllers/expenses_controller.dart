import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../reservations/models/reservation_item.dart';
import '../../../reservations/presentation/controllers/reservations_controller.dart';
import '../../data/expenses_repository.dart';
import '../../models/expense_item.dart';

class ExpensesState {
  const ExpensesState({
    required this.result,
    required this.search,
    required this.reservationId,
    required this.programId,
    required this.budgetSectionId,
  });

  final PagedResult<ExpenseItem> result;
  final String search;
  final String? reservationId;
  final String? programId;
  final String? budgetSectionId;
}

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(apiClientProvider)),
);

final spendableReservationsProvider = FutureProvider<List<ReservationItem>>((
  ref,
) async {
  final repository = ref.watch(reservationsRepositoryProvider);
  final result = await repository.fetchReservations(
    search: '',
    status: null,
    programId: null,
    budgetSectionId: null,
    fundingId: null,
    executionStatus: null,
    page: 1,
    pageSize: 300,
  );

  return result.items
      // تعليق عربي: الصرف يتم فقط من حجز معتمد، وليس من الحجز المحجوز أو الملغي.
      .where((item) => item.workflowStatus == 'approved')
      .toList();
});

final expensesControllerProvider =
    AsyncNotifierProvider<ExpensesController, ExpensesState>(
      ExpensesController.new,
    );

class ExpensesController extends AsyncNotifier<ExpensesState> {
  static const _pageSize = 10;

  ExpensesRepository get _repository => ref.read(expensesRepositoryProvider);

  @override
  Future<ExpensesState> build() async => _fetch(
    search: '',
    reservationId: null,
    programId: null,
    budgetSectionId: null,
    page: 1,
  );

  Future<ExpensesState> _fetch({
    required String search,
    required String? reservationId,
    required String? programId,
    required String? budgetSectionId,
    required int page,
  }) async {
    final result = await _repository.fetchExpenses(
      search: search,
      reservationId: reservationId,
      programId: programId,
      budgetSectionId: budgetSectionId,
      page: page,
      pageSize: _pageSize,
    );

    return ExpensesState(
      result: result,
      search: search,
      reservationId: reservationId,
      programId: programId,
      budgetSectionId: budgetSectionId,
    );
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.asData?.value;
    if (showLoading) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        reservationId: current?.reservationId,
        programId: current?.programId,
        budgetSectionId: current?.budgetSectionId,
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? reservationId,
    String? programId,
    String? budgetSectionId,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: search ?? current?.search ?? '',
        reservationId: reservationId == ''
            ? null
            : (reservationId ?? current?.reservationId),
        programId: programId == '' ? null : (programId ?? current?.programId),
        budgetSectionId: budgetSectionId == ''
            ? null
            : (budgetSectionId ?? current?.budgetSectionId),
        page: 1,
      ),
    );
  }

  Future<void> changePage(int page) async {
    final current = state.asData?.value;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current.search,
        reservationId: current.reservationId,
        programId: current.programId,
        budgetSectionId: current.budgetSectionId,
        page: page,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createExpense(payload);
    ref.invalidate(spendableReservationsProvider);
    await refresh();
  }

  Future<void> cancel(String id, String reason) async {
    await _repository.cancelExpense(id: id, reason: reason);
    ref.invalidate(spendableReservationsProvider);
    await refresh();
  }
}
