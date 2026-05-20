import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/budget_sections_repository.dart';
import '../../models/budget_section_item.dart';

class BudgetSectionsState {
  const BudgetSectionsState({
    required this.result,
    required this.search,
    required this.programId,
    required this.fiscalYearId,
    required this.budgetTypeId,
  });

  final PagedResult<BudgetSectionItem> result;
  final String search;
  final String? programId;
  final String? fiscalYearId;
  final String? budgetTypeId;
}

final budgetSectionsRepositoryProvider = Provider<BudgetSectionsRepository>(
  (ref) => BudgetSectionsRepository(ref.watch(apiClientProvider)),
);

final allBudgetSectionsLookupProvider = FutureProvider<List<BudgetSectionItem>>(
  (ref) async {
    final repository = ref.watch(budgetSectionsRepositoryProvider);
    final result = await repository.fetchBudgetSections(
      search: '',
      programId: null,
      fiscalYearId: null,
      budgetTypeId: null,
      page: 1,
      pageSize: 1000,
    );
    return result.items;
  },
);

final budgetSectionsControllerProvider =
    AsyncNotifierProvider<BudgetSectionsController, BudgetSectionsState>(
      BudgetSectionsController.new,
    );

class BudgetSectionsController extends AsyncNotifier<BudgetSectionsState> {
  // تعليق عربي: شاشة الأبواب أصبحت شجرية؛ نعرض عدداً كبيراً حتى لا تنقطع الفروع بين الصفحات.
  static const _pageSize = 1000;

  BudgetSectionsRepository get _repository =>
      ref.read(budgetSectionsRepositoryProvider);

  @override
  Future<BudgetSectionsState> build() async => _fetch(
    search: '',
    page: 1,
    programId: null,
    fiscalYearId: null,
    budgetTypeId: null,
  );

  Future<BudgetSectionsState> _fetch({
    required String search,
    required int page,
    required String? programId,
    required String? fiscalYearId,
    required String? budgetTypeId,
  }) async {
    final result = await _repository.fetchBudgetSections(
      search: search,
      programId: programId,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
      page: page,
      pageSize: _pageSize,
    );
    return BudgetSectionsState(
      result: result,
      search: search,
      programId: programId,
      fiscalYearId: fiscalYearId,
      budgetTypeId: budgetTypeId,
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
        fiscalYearId: current?.fiscalYearId,
        budgetTypeId: current?.budgetTypeId,
      ),
    );
  }

  Future<void> applyFilters({
    String? search,
    String? programId,
    String? fiscalYearId,
    String? budgetTypeId,
  }) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: search ?? current?.search ?? '',
        page: 1,
        programId: programId == '' ? null : (programId ?? current?.programId),
        fiscalYearId: fiscalYearId == ''
            ? null
            : (fiscalYearId ?? current?.fiscalYearId),
        budgetTypeId: budgetTypeId == ''
            ? null
            : (budgetTypeId ?? current?.budgetTypeId),
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
        fiscalYearId: current.fiscalYearId,
        budgetTypeId: current.budgetTypeId,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createBudgetSection(payload);
    await refresh();
    ref.invalidate(allBudgetSectionsLookupProvider);
  }

  Future<void> updateBudgetSection(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await _repository.updateBudgetSection(id: id, payload: payload);
    await refresh();
    ref.invalidate(allBudgetSectionsLookupProvider);
  }

  Future<void> remove(String id) async {
    await _repository.deleteBudgetSection(id);
    await refresh();
    ref.invalidate(allBudgetSectionsLookupProvider);
  }
}
