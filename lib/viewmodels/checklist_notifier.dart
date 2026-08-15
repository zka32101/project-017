import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/submission_checklist_item.dart';
import 'service_providers.dart';

/// 提出前チェックリストの状態管理（Should機能、設計書 v1.4新設）。
/// connectedAppId ごとに独立した状態を持つ（FamilyNotifier）。
class ChecklistNotifier extends FamilyNotifier<List<SubmissionChecklistItem>, String> {
  late final String _connectedAppId;

  @override
  List<SubmissionChecklistItem> build(String connectedAppId) {
    _connectedAppId = connectedAppId;
    return ref.read(checklistServiceProvider).defaultChecklistFor(connectedAppId);
  }

  Future<void> setResult(
    ChecklistItemKey key,
    ChecklistResult result,
    DateTime checkedAt,
  ) async {
    state = [
      for (final item in state)
        if (item.itemKey == key)
          item.copyWithResult(result, checkedAt)
        else
          item,
    ];
    await ref.read(localStoreServiceProvider).saveChecklist(_connectedAppId, state);
  }

  /// 永続化データからの復元用。checklistBootstrapProvider から呼ばれる
  /// （build() 内の暗黙的な副作用にしない理由は connected_apps_notifier.dart の
  /// appBootstrapProvider のコメントを参照）。
  ///
  /// stateをsavedへ丸ごと置き換えるのではなく、現在のstate（build()時点で
  /// defaultChecklistFor()から生成された、現行のChecklistItemKey.values全件）を
  /// ベースに、savedにある結果だけをitemKey単位で上書きする。四半期メンテナンス
  /// でChecklistItemKeyが増減した場合でも、新規項目の欠落や削除済みキーの
  /// 残留が起きないようにするため。
  void restore(List<SubmissionChecklistItem> saved) {
    final savedByKey = {for (final item in saved) item.itemKey: item};
    state = [
      for (final item in state) savedByKey[item.itemKey] ?? item,
    ];
  }

  /// pass判定の件数（①AIリジェクト診断[Could]と対になる事前対応の進捗表示用）
  int get passCount => state.where((i) => i.result == ChecklistResult.pass).length;

  bool get allPassed =>
      state.isNotEmpty && state.every((i) => i.result == ChecklistResult.pass);
}

final checklistProvider =
    NotifierProvider.family<ChecklistNotifier, List<SubmissionChecklistItem>, String>(
  ChecklistNotifier.new,
);

/// connectedAppIdごとに一度だけ、永続化されたチェックリスト進捗を復元する。
/// ChecklistNotifier.build()内の暗黙的な副作用として自動発火させるのではなく、
/// ChecklistScreen側から明示的にwatchする設計にしている理由は
/// connected_apps_notifier.dart の appBootstrapProvider と同じ:
/// build()内で自動発火すると、ProviderContainerを作って即座にsetResultを呼ぶ
/// 既存の単体テスト群と非同期のタイミングが競合しかねないため。
final checklistBootstrapProvider =
    FutureProvider.family<void, String>((ref, connectedAppId) async {
  final saved =
      await ref.read(localStoreServiceProvider).loadChecklist(connectedAppId);
  if (saved != null && saved.isNotEmpty) {
    ref.read(checklistProvider(connectedAppId).notifier).restore(saved);
  }
});
