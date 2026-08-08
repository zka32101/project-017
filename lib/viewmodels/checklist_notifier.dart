import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/submission_checklist_item.dart';
import 'service_providers.dart';

/// 提出前チェックリストの状態管理（Should機能、設計書 v1.4新設）。
/// connectedAppId ごとに独立した状態を持つ（FamilyNotifier）。
class ChecklistNotifier extends FamilyNotifier<List<SubmissionChecklistItem>, String> {
  @override
  List<SubmissionChecklistItem> build(String connectedAppId) {
    return ref.read(checklistServiceProvider).defaultChecklistFor(connectedAppId);
  }

  void setResult(ChecklistItemKey key, ChecklistResult result, DateTime checkedAt) {
    state = [
      for (final item in state)
        if (item.itemKey == key)
          item.copyWithResult(result, checkedAt)
        else
          item,
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
