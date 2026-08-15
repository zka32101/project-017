// ウィジェットテスト共通のフェイク群。
// SecureStorageService(flutter_secure_storage)・LocalStoreService(path_provider)・
// WidgetSyncService(home_widget) はいずれも実機のプラットフォームチャネルに
//依存する実装のため、flutter test 環境では未モックのMethodChannel呼び出しが
// 例外になる。widget_test.dart や各viewmodelの単体テストと同じ理由で、
// ここに集約したインメモリ/no-opのフェイクをProviderScopeのoverridesとして渡す。

import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/services/widget_sync_service.dart';

class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async {
    _memory[SecureStorageService.refKeyFor(connectedAppId)] = apiKey;
  }

  @override
  Future<String?> readApiKey(String connectedAppId) async =>
      _memory[SecureStorageService.refKeyFor(connectedAppId)];

  @override
  Future<void> deleteApiKey(String connectedAppId) async {
    _memory.remove(SecureStorageService.refKeyFor(connectedAppId));
  }
}

/// load()/loadChecklist()に固定の初期値を差し込める、永続化なしのフェイク。
/// デフォルト（初期値省略）ではデモアプリ自動投入の対象になる「保存データなし」状態。
class FakeLocalStoreService extends LocalStoreService {
  FakeLocalStoreService({LocalState? initial}) : _stored = initial;

  LocalState? _stored;

  @override
  Future<LocalState?> load() async => _stored;

  @override
  Future<void> save(LocalState state) async {
    _stored = state;
  }

  @override
  Future<List<SubmissionChecklistItem>?> loadChecklist(
    String connectedAppId,
  ) async =>
      null;

  @override
  Future<void> saveChecklist(
    String connectedAppId,
    List<SubmissionChecklistItem> items,
  ) async {}

  @override
  Future<void> deleteChecklist(String connectedAppId) async {}
}

class FakeWidgetSyncService extends WidgetSyncService {
  const FakeWidgetSyncService();

  @override
  Future<void> syncSummary({
    required int totalApps,
    required int attentionCount,
    required ConnectedApp? topAttentionApp,
  }) async {}
}
