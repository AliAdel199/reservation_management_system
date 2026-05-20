import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/monthly_fundings_repository.dart';
import '../../models/monthly_funding_item.dart';

class MonthlyFundingsState {
  const MonthlyFundingsState({
    required this.result,
    required this.search,
    required this.fiscalYearId,
    required this.budgetTypeId,
    required this.programId,
    required this.sectionId,
    required this.month,
  });

  final PagedResult<MonthlyFundingItem> result;
  final String search;
  final String? fiscalYearId;
  final String? budgetTypeId;
  final String? programId;
  final String? sectionId;
  final int? month;
}

final monthlyFundingsRepositoryProvider = Provider<MonthlyFundingsRepository>(
  (ref) => MonthlyFundingsRepository(ref.watch(apiClientProvider)),
);

final monthlyFundingsControllerProvider =
    AsyncNotifierProvider<MonthlyFundingsController, MonthlyFundingsState>(
      MonthlyFundingsController.new,
    );

class MonthlyFundingsController extends AsyncNotifier<MonthlyFundingsState> {
  static const _pageSize = 10;

  MonthlyFundingsRepository get _repository =>
      ref.read(monthlyFundingsRepositoryProvider);

  @override
  Future<MonthlyFundingsState> build() async => _fetch(
    search: '',
    fiscalYearId: null,
    budgetTypeId: null,
    programId: null,
    sectionId: null,
    month: null,
    page: 1,
  );

  Future<MonthlyFundingsState> _fetch({
    required String search,
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String? programId,
    required String? sectionId,
    required int? month,
    required int page,
  }) async {
    final result = await _repository.fetchMonthlyFundings(
      search: search,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
      programId: programId,
      sectionId: sectionId,
      month: month,
      page: page,
      pageSize: _pageSize,
    );
    return MonthlyFundingsState(
      result: result,
      search: search,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
      programId: programId,
      sectionId: sectionId,
      month: month,
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
        fiscalYearId: current?.fiscalYearId,
        budgetTypeId: current?.budgetTypeId,
        programId: current?.programId,
        sectionId: current?.sectionId,
        month: current?.month,
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? fiscalYearId,
    String? budgetTypeId,
    String? programId,
    String? sectionId,
    int? month,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: search ?? current?.search ?? '',
        fiscalYearId: fiscalYearId == ''
            ? null
            : (fiscalYearId ?? current?.fiscalYearId),
        budgetTypeId: budgetTypeId == ''
            ? null
            : (budgetTypeId ?? current?.budgetTypeId),
        programId: programId == '' ? null : (programId ?? current?.programId),
        sectionId: sectionId == '' ? null : (sectionId ?? current?.sectionId),
        month: month == 0 ? null : (month ?? current?.month),
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
        fiscalYearId: current.fiscalYearId,
        budgetTypeId: current.budgetTypeId,
        programId: current.programId,
        sectionId: current.sectionId,
        month: current.month,
        page: page,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createMonthlyFunding(payload);
    await refresh();
  }

  Future<void> updateMonthlyFunding(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _repository.updateMonthlyFunding(id: id, payload: payload);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repository.deleteMonthlyFunding(id);
    await refresh();
  }
}
