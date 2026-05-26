import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/backups_repository.dart';
import '../../models/database_backup_item.dart';

final backupsRepositoryProvider = Provider<BackupsRepository>(
  (ref) => BackupsRepository(ref.watch(apiClientProvider)),
);

final backupsControllerProvider =
    AsyncNotifierProvider<BackupsController, List<DatabaseBackupItem>>(
      BackupsController.new,
    );

class BackupsController extends AsyncNotifier<List<DatabaseBackupItem>> {
  BackupsRepository get _repository => ref.read(backupsRepositoryProvider);

  @override
  Future<List<DatabaseBackupItem>> build() => _repository.fetchBackups();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchBackups);
  }

  Future<void> createBackup() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.createBackup();
      return _repository.fetchBackups();
    });
  }

  Future<void> restoreBackup(String fileName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.restoreBackup(fileName);
      return _repository.fetchBackups();
    });
  }
}
