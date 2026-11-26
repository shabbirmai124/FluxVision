import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_vault_storage.dart';
import '../../core/storage/vault_models.dart';

final localVaultStorageProvider = Provider<LocalVaultStorage>(
  (ref) => LocalVaultStorage(),
);

final vaultControllerProvider = AsyncNotifierProvider<VaultController, VaultState>(
  VaultController.new,
);

@immutable
class VaultState {
  const VaultState({
    required this.baselines,
    required this.sessions,
  });

  final List<RoomBaseline> baselines;
  final List<ScanSession> sessions;
}

/// Manages offline RoomBaselines and saved ScanSessions persisted in LocalVaultStorage.
class VaultController extends AsyncNotifier<VaultState> {
  @override
  Future<VaultState> build() async {
    return _loadAll();
  }

  Future<VaultState> _loadAll() async {
    final storage = ref.read(localVaultStorageProvider);
    final results = await Future.wait<Object>(<Future<Object>>[
      storage.loadBaselines(),
      storage.loadSessions(),
    ]);
    return VaultState(
      baselines: results[0] as List<RoomBaseline>,
      sessions: results[1] as List<ScanSession>,
    );
  }

  Future<void> refresh() async {
    final loaded = await AsyncValue.guard<VaultState>(_loadAll);
    if (!ref.mounted) return;
    state = loaded;
  }

  Future<void> saveBaseline(RoomBaseline baseline) async {
    final storage = ref.read(localVaultStorageProvider);
    await storage.saveBaseline(baseline);
    await refresh();
  }

  Future<void> deleteBaseline(String id) async {
    final storage = ref.read(localVaultStorageProvider);
    await storage.deleteBaseline(id);
    await refresh();
  }

  Future<void> deleteSession(String id) async {
    final storage = ref.read(localVaultStorageProvider);
    await storage.deleteSession(id);
    await refresh();
  }
}
