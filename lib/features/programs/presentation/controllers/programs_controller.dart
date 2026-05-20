import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/programs_repository.dart';
import '../../models/program_item.dart';

class ProgramsState {
  const ProgramsState({
    required this.result,
    required this.search,
    required this.fiscalYearId,
  });

  final PagedResult<ProgramItem> result;
  final String search;
  final String? fiscalYearId;
}

final programsRepositoryProvider = Provider<ProgramsRepository>(
  (ref) => ProgramsRepository(ref.watch(apiClientProvider)),
);

final programLookupProvider = FutureProvider<List<ProgramItem>>(
  (ref) => ref.watch(programsRepositoryProvider).fetchProgramLookup(),
);

final programsControllerProvider =
    AsyncNotifierProvider<ProgramsController, ProgramsState>(
      ProgramsController.new,
    );

class ProgramsController extends AsyncNotifier<ProgramsState> {
  static const _pageSize = 10;

  ProgramsRepository get _repository => ref.read(programsRepositoryProvider);

  @override
  Future<ProgramsState> build() async =>
      _fetch(search: '', fiscalYearId: null, page: 1);

  Future<ProgramsState> _fetch({
    required String search,
    required String? fiscalYearId,
    required int page,
  }) async {
    final result = await _repository.fetchPrograms(
      search: search,
      fiscalYearId: fiscalYearId,
      page: page,
      pageSize: _pageSize,
    );
    return ProgramsState(
      result: result,
      search: search,
      fiscalYearId: fiscalYearId,
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        fiscalYearId: current?.fiscalYearId,
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> search(String search) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () =>
          _fetch(search: search, fiscalYearId: current?.fiscalYearId, page: 1),
    );
  }

  Future<void> filterFiscalYear(String? fiscalYearId) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        fiscalYearId: fiscalYearId?.isEmpty == true ? null : fiscalYearId,
        page: 1,
      ),
    );
  }

  Future<void> resetFilters() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(search: '', fiscalYearId: null, page: 1),
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
        page: page,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createProgram(payload);
    await refresh();
    ref.invalidate(programLookupProvider);
  }

  Future<void> updateProgram(String id, Map<String, dynamic> payload) async {
    await _repository.updateProgram(id: id, payload: payload);
    await refresh();
    ref.invalidate(programLookupProvider);
  }

  Future<void> remove(String id) async {
    await _repository.deleteProgram(id);
    await refresh();
    ref.invalidate(programLookupProvider);
  }
}
