import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reservations_repository.dart';
import '../../models/reservation_item.dart';

class ReservationsState {
  const ReservationsState({
    required this.result,
    required this.search,
    required this.status,
    required this.programId,
    required this.budgetSectionId,
    required this.fundingId,
    required this.executionStatus,
  });

  final PagedResult<ReservationItem> result;
  final String search;
  final String? status;
  final String? programId;
  final String? budgetSectionId;
  final String? fundingId;
  final String? executionStatus;
}

final reservationsRepositoryProvider = Provider<ReservationsRepository>(
  (ref) => ReservationsRepository(ref.watch(apiClientProvider)),
);

final reservationsControllerProvider =
    AsyncNotifierProvider<ReservationsController, ReservationsState>(
      ReservationsController.new,
    );

class ReservationsController extends AsyncNotifier<ReservationsState> {
  static const _pageSize = 10;

  ReservationsRepository get _repository =>
      ref.read(reservationsRepositoryProvider);

  @override
  Future<ReservationsState> build() async => _fetch(
    search: '',
    status: null,
    programId: null,
    budgetSectionId: null,
    fundingId: null,
    executionStatus: null,
    page: 1,
  );

  Future<ReservationsState> _fetch({
    required String search,
    required String? status,
    required String? programId,
    required String? budgetSectionId,
    required String? fundingId,
    required String? executionStatus,
    required int page,
  }) async {
    final result = await _repository.fetchReservations(
      search: search,
      status: status,
      programId: programId,
      budgetSectionId: budgetSectionId,
      fundingId: fundingId,
      executionStatus: executionStatus,
      page: page,
      pageSize: _pageSize,
    );

    return ReservationsState(
      result: result,
      search: search,
      status: status,
      programId: programId,
      budgetSectionId: budgetSectionId,
      fundingId: fundingId,
      executionStatus: executionStatus,
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
        status: current?.status,
        programId: current?.programId,
        budgetSectionId: current?.budgetSectionId,
        fundingId: current?.fundingId,
        executionStatus: current?.executionStatus,
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? status,
    String? programId,
    String? budgetSectionId,
    String? fundingId,
    String? executionStatus,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: search ?? current?.search ?? '',
        status: status == '' ? null : (status ?? current?.status),
        programId: programId == '' ? null : (programId ?? current?.programId),
        budgetSectionId: budgetSectionId == ''
            ? null
            : (budgetSectionId ?? current?.budgetSectionId),
        fundingId: fundingId == '' ? null : (fundingId ?? current?.fundingId),
        executionStatus: executionStatus == ''
            ? null
            : (executionStatus ?? current?.executionStatus),
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
        status: current.status,
        programId: current.programId,
        budgetSectionId: current.budgetSectionId,
        fundingId: current.fundingId,
        executionStatus: current.executionStatus,
        page: page,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createReservation(payload);
    await refresh();
  }

  Future<void> updateReservation(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _repository.updateReservation(id: id, payload: payload);
    await refresh();
  }

  Future<void> submitReservation(String id) async {
    await _repository.submitForReview(id);
    await refresh();
  }

  Future<void> approveReservation(String id) async {
    await _repository.approve(id);
    await refresh();
  }

  Future<void> cancelReservation(String id) async {
    await _repository.cancel(id);
    await refresh();
  }

  Future<void> deleteReservation(String id) async {
    await _repository.deleteReservation(id);
    await refresh();
  }
}
