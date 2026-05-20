import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/audit_logs_repository.dart';
import '../../models/audit_log_item.dart';

class AuditLogsState {
  const AuditLogsState({required this.result, required this.search});

  final PagedResult<AuditLogItem> result;
  final String search;
}

final auditLogsRepositoryProvider = Provider<AuditLogsRepository>(
  (ref) => AuditLogsRepository(ref.watch(apiClientProvider)),
);

final auditLogsControllerProvider =
    AsyncNotifierProvider<AuditLogsController, AuditLogsState>(
      AuditLogsController.new,
    );

class AuditLogsController extends AsyncNotifier<AuditLogsState> {
  static const _pageSize = 20;

  AuditLogsRepository get _repository => ref.read(auditLogsRepositoryProvider);

  @override
  Future<AuditLogsState> build() => _fetch(search: '', page: 1);

  Future<AuditLogsState> _fetch({
    required String search,
    required int page,
  }) async {
    final result = await _repository.fetchAuditLogs(
      search: search,
      page: page,
      pageSize: _pageSize,
    );
    return AuditLogsState(result: result, search: search);
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.asData?.value;
    if (showLoading) state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> search(String value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(search: value, page: 1));
  }

  Future<void> changePage(int page) async {
    final current = state.asData?.value;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(search: current.search, page: page),
    );
  }
}
