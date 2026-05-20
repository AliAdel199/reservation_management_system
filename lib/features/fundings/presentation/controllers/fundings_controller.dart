import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/fundings_repository.dart';
import '../../models/funding_item.dart';

class FundingsState {
  const FundingsState({
    required this.result,
    required this.search,
    required this.programId,
    required this.budgetSectionId,
  });

  final PagedResult<FundingItem> result;
  final String search;
  final String? programId;
  final String? budgetSectionId;
}

final fundingsRepositoryProvider = Provider<FundingsRepository>(
  (ref) => FundingsRepository(ref.watch(apiClientProvider)),
);

final fundingsLookupProvider = FutureProvider<List<FundingItem>>((ref) async {
  final repository = ref.watch(fundingsRepositoryProvider);
  final result = await repository.fetchFundings(
    search: '',
    programId: null,
    budgetSectionId: null,
    page: 1,
    pageSize: 1000,
  );
  return result.items;
});

final fundingsControllerProvider =
    AsyncNotifierProvider<FundingsController, FundingsState>(
      FundingsController.new,
    );

class FundingsController extends AsyncNotifier<FundingsState> {
  static const _pageSize = 10;

  FundingsRepository get _repository => ref.read(fundingsRepositoryProvider);

  @override
  Future<FundingsState> build() async =>
      _fetch(search: '', page: 1, programId: null, budgetSectionId: null);

  Future<FundingsState> _fetch({
    required String search,
    required int page,
    required String? programId,
    required String? budgetSectionId,
  }) async {
    final result = await _repository.fetchFundings(
      search: search,
      programId: programId,
      budgetSectionId: budgetSectionId,
      page: page,
      pageSize: _pageSize,
    );
    return FundingsState(
      result: result,
      search: search,
      programId: programId,
      budgetSectionId: budgetSectionId,
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        page: current?.result.pagination.page ?? 1,
        programId: current?.programId,
        budgetSectionId: current?.budgetSectionId,
      ),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? programId,
    String? budgetSectionId,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: search ?? current?.search ?? '',
        page: 1,
        programId: programId == '' ? null : (programId ?? current?.programId),
        budgetSectionId: budgetSectionId == ''
            ? null
            : (budgetSectionId ?? current?.budgetSectionId),
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
        page: page,
        programId: current.programId,
        budgetSectionId: current.budgetSectionId,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createFunding(payload);
    await refresh();
    ref.invalidate(fundingsLookupProvider);
  }

  Future<void> updateFunding(String id, Map<String, dynamic> payload) async {
    await _repository.updateFunding(id: id, payload: payload);
    await refresh();
    ref.invalidate(fundingsLookupProvider);
  }
}
