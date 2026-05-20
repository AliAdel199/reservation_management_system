import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/fiscal_years_repository.dart';
import '../../models/fiscal_year_item.dart';

class FiscalYearsState {
  const FiscalYearsState({required this.result, required this.search});

  final PagedResult<FiscalYearItem> result;
  final String search;
}

final fiscalYearsRepositoryProvider = Provider<FiscalYearsRepository>(
  (ref) => FiscalYearsRepository(ref.watch(apiClientProvider)),
);

final fiscalYearsLookupProvider = FutureProvider<List<FiscalYearItem>>((
  ref,
) async {
  final result = await ref
      .watch(fiscalYearsRepositoryProvider)
      .fetchFiscalYears(search: '', page: 1, pageSize: 1000);
  return result.items;
});

final fiscalYearsControllerProvider =
    AsyncNotifierProvider<FiscalYearsController, FiscalYearsState>(
      FiscalYearsController.new,
    );

class FiscalYearsController extends AsyncNotifier<FiscalYearsState> {
  static const _pageSize = 10;

  FiscalYearsRepository get _repository =>
      ref.read(fiscalYearsRepositoryProvider);

  @override
  Future<FiscalYearsState> build() async => _fetch(search: '', page: 1);

  Future<FiscalYearsState> _fetch({
    required String search,
    required int page,
  }) async {
    final result = await _repository.fetchFiscalYears(
      search: search,
      page: page,
      pageSize: _pageSize,
    );
    return FiscalYearsState(result: result, search: search);
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
    await _repository.createFiscalYear(payload);
    await refresh();
    ref.invalidate(fiscalYearsLookupProvider);
  }

  Future<void> updateFiscalYear(String id, Map<String, dynamic> payload) async {
    await _repository.updateFiscalYear(id: id, payload: payload);
    await refresh();
    ref.invalidate(fiscalYearsLookupProvider);
  }

  Future<void> activate(String id) async {
    await _repository.activateFiscalYear(id);
    await refresh();
    ref.invalidate(fiscalYearsLookupProvider);
  }

  Future<void> remove(String id) async {
    await _repository.deleteFiscalYear(id);
    await refresh();
    ref.invalidate(fiscalYearsLookupProvider);
  }
}
