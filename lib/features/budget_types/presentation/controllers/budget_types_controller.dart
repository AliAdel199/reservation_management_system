import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/budget_types_repository.dart';
import '../../models/budget_type_item.dart';

class BudgetTypesState {
  const BudgetTypesState({required this.result, required this.search});

  final PagedResult<BudgetTypeItem> result;
  final String search;
}

final budgetTypesRepositoryProvider = Provider<BudgetTypesRepository>(
  (ref) => BudgetTypesRepository(ref.watch(apiClientProvider)),
);

final budgetTypesLookupProvider = FutureProvider<List<BudgetTypeItem>>((
  ref,
) async {
  final result = await ref
      .watch(budgetTypesRepositoryProvider)
      .fetchBudgetTypes(search: '', page: 1, pageSize: 1000);
  return result.items;
});

final budgetTypesControllerProvider =
    AsyncNotifierProvider<BudgetTypesController, BudgetTypesState>(
      BudgetTypesController.new,
    );

class BudgetTypesController extends AsyncNotifier<BudgetTypesState> {
  static const _pageSize = 10;

  BudgetTypesRepository get _repository =>
      ref.read(budgetTypesRepositoryProvider);

  @override
  Future<BudgetTypesState> build() async => _fetch(search: '', page: 1);

  Future<BudgetTypesState> _fetch({
    required String search,
    required int page,
  }) async {
    final result = await _repository.fetchBudgetTypes(
      search: search,
      page: page,
      pageSize: _pageSize,
    );
    return BudgetTypesState(result: result, search: search);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> search(String search) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(search: search, page: 1));
  }

  Future<void> changePage(int page) async {
    final current = state.asData?.value;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(search: current.search, page: page),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createBudgetType(payload);
    await refresh();
    ref.invalidate(budgetTypesLookupProvider);
  }

  Future<void> updateBudgetType(String id, Map<String, dynamic> payload) async {
    await _repository.updateBudgetType(id: id, payload: payload);
    await refresh();
    ref.invalidate(budgetTypesLookupProvider);
  }

  Future<void> remove(String id) async {
    await _repository.deleteBudgetType(id);
    await refresh();
    ref.invalidate(budgetTypesLookupProvider);
  }
}
