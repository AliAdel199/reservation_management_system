import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/institution_repository.dart';
import '../../models/institution_settings_item.dart';

final institutionRepositoryProvider = Provider<InstitutionRepository>(
  (ref) => InstitutionRepository(ref.watch(apiClientProvider)),
);

final institutionControllerProvider =
    AsyncNotifierProvider<InstitutionController, InstitutionSettingsItem>(
      InstitutionController.new,
    );

class InstitutionController extends AsyncNotifier<InstitutionSettingsItem> {
  InstitutionRepository get _repository =>
      ref.read(institutionRepositoryProvider);

  @override
  Future<InstitutionSettingsItem> build() => _repository.fetchSettings();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchSettings);
  }

  Future<void> save(Map<String, dynamic> payload) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.updateSettings(payload));
  }
}
