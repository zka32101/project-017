import 'package:home_widget/home_widget.dart';

import '../models/connected_app.dart';
import '../models/review_status_type.dart';

/// ホーム画面ウィジェット（Should機能）の土台。
/// ダッシュボードのサマリー（要注意アプリ数・最新状態）をネイティブ側の
/// AppWidgetProvider（Android）/ WidgetKit（iOS）が読める共有ストレージへ書き込む。
///
/// 【スコープ注記】Android側のAppWidgetProvider実装（Kotlin+XML）は本セッションで用意済み
/// （android/app/src/main/kotlin/.../RirikanStatusWidgetProvider.kt）。
/// iOS側のWidgetKit Extensionは Xcode プロジェクトの新規ターゲット追加が必須で、
/// Windows環境では実装・検証ができないため未着手（次フェーズ、Mac環境での対応が必要）。
class WidgetSyncService {
  const WidgetSyncService();

  static const _keyAppCount = 'ririkan_app_count';
  static const _keyAttentionCount = 'ririkan_attention_count';
  static const _keyLatestSummary = 'ririkan_latest_summary';
  static const _keyUpdatedAt = 'ririkan_updated_at';

  /// 「要注意」とみなす審査状態（リジェクト・審査中はウィジェットで目立たせる対象）。
  static const _attentionStatuses = {
    ReviewStatusType.rejected,
    ReviewStatusType.inReview,
  };

  bool isAttentionStatus(ReviewStatusType status) =>
      _attentionStatuses.contains(status);

  /// ダッシュボードの現在状態をウィジェット用ストレージへ反映し、ネイティブ側へ更新を通知する。
  Future<void> syncSummary({
    required int totalApps,
    required int attentionCount,
    required ConnectedApp? topAttentionApp,
  }) async {
    // 4つとも独立したキーへの書き込みのため、直列awaitではなくまとめて並行実行する。
    await Future.wait([
      HomeWidget.saveWidgetData<int>(_keyAppCount, totalApps),
      HomeWidget.saveWidgetData<int>(_keyAttentionCount, attentionCount),
      HomeWidget.saveWidgetData<String>(
        _keyLatestSummary,
        topAttentionApp == null ? '' : topAttentionApp.displayName,
      ),
      HomeWidget.saveWidgetData<String>(
        _keyUpdatedAt,
        DateTime.now().toIso8601String(),
      ),
    ]);

    await HomeWidget.updateWidget(
      androidName: 'RirikanStatusWidgetProvider',
      qualifiedAndroidName: 'com.yourwish.ririkan.RirikanStatusWidgetProvider',
      iOSName: 'RirikanStatusWidget',
    );
  }
}
