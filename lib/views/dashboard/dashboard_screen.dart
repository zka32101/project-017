import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connected_app.dart';
import '../../models/platform_type.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/dashboard_providers.dart';
import '../../viewmodels/widget_sync_provider.dart';

/// ダッシュボード(Aha Moment): 登録アプリの現在状態が一覧表示される瞬間。
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(sortedConnectedAppsProvider);
    final plan = ref.watch(userPlanProvider);
    // ホーム画面ウィジェット用データを常に最新化する（Should機能の土台、失敗しても画面表示は継続）。
    ref.watch(widgetSyncProvider);

    // 起動時に一度だけ、永続化データの復元 or デモアプリの自動投入を行う
    // （オンボーディング→アプリ登録フロー不要で、直接ダッシュボードからテスト開始可能）。
    // AsyncValueは使わずbareでwatchするだけなので、失敗してもこの画面自体は
    // クラッシュしない（appsが空のままなら _EmptyDashboard が表示される）。
    ref.watch(appBootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('リリカン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: apps.isEmpty
          ? const _EmptyDashboard()
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: apps.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(connectedAppsProvider.notifier)
                  .reorder(oldIndex, newIndex),
              itemBuilder: (context, i) => _AppStatusCard(
                key: ValueKey(apps[i].id),
                app: apps[i],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final notifier = ref.read(connectedAppsProvider.notifier);
          if (notifier.wouldHitPaywall(plan)) {
            context.push('/paywall');
          } else {
            context.push('/app-registration');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('アプリを追加'),
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('まだ登録アプリがありません',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AppStatusCard extends ConsumerWidget {
  final ConnectedApp app;
  const _AppStatusCard({super.key, required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(latestReviewStatusProvider(app));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/app-detail/${app.id}', extra: app),
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceVariant,
          child: Text(app.platform == PlatformType.ios ? 'iOS' : 'And',
              style: const TextStyle(fontSize: 10)),
        ),
        title: Text(app.displayName),
        subtitle: statusAsync.when(
          data: (s) => Text(s == null ? '状態未取得' : '${s.versionString} ・ ${s.statusType.label}'),
          loading: () => const Text('取得中…'),
          error: (e, _) => Text('$e', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        trailing: statusAsync.when(
          data: (s) => Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s == null
                  ? AppTheme.textSecondary
                  : AppTheme.colorForStatusKey(s.statusType.name),
            ),
          ),
          loading: () => const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: AppTheme.danger),
            tooltip: '再試行',
            onPressed: () => ref.invalidate(latestReviewStatusProvider(app)),
          ),
        ),
      ),
    );
  }
}
