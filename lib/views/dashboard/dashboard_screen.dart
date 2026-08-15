import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
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
    final l10n = AppLocalizations.of(context);
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
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: apps.isEmpty
          ? _EmptyDashboard(message: l10n.dashboardEmptyMessage)
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
        label: Text(l10n.dashboardAddApp),
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  final String message;
  const _EmptyDashboard({required this.message});

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
            Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
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
    final l10n = AppLocalizations.of(context);
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
          data: (s) => Text(s == null
              ? l10n.dashboardStatusUnknown
              : '${s.versionString} ・ ${s.statusType.label(l10n)}'),
          loading: () => Text(l10n.dashboardStatusLoading),
          error: (e, _) => Text(localizedErrorMessage(l10n, e),
              maxLines: 1, overflow: TextOverflow.ellipsis),
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
            tooltip: l10n.commonRetry,
            onPressed: () => ref.invalidate(latestReviewStatusProvider(app)),
          ),
        ),
      ),
    );
  }
}
