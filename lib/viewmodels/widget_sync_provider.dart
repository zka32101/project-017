import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../services/widget_sync_service.dart';
import 'dashboard_providers.dart';

final widgetSyncServiceProvider =
    Provider<WidgetSyncService>((ref) => const WidgetSyncService());

/// ダッシュボードの登録アプリ・審査状態が変わるたびにホーム画面ウィジェット用データを同期する
/// （Should機能の土台）。DashboardScreenからref.watchすることで自動的に反映される。
final widgetSyncProvider = FutureProvider<void>((ref) async {
  final apps = ref.watch(sortedConnectedAppsProvider);
  final service = ref.watch(widgetSyncServiceProvider);

  ConnectedApp? topAttentionApp;
  var attentionCount = 0;

  for (final app in apps) {
    final statusAsync = await ref.watch(latestReviewStatusProvider(app).future);
    if (statusAsync != null && service.isAttentionStatus(statusAsync.statusType)) {
      attentionCount++;
      topAttentionApp ??= app;
    }
  }

  await service.syncSummary(
    totalApps: apps.length,
    attentionCount: attentionCount,
    topAttentionApp: topAttentionApp,
  );
});
