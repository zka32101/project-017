import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
import '../../models/connected_app.dart';
import '../../models/platform_type.dart';
import '../../models/user_plan.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/dashboard_providers.dart';
import '../../viewmodels/service_providers.dart';
import '../../viewmodels/widget_sync_provider.dart';

/// ダッシュボード(Aha Moment): 登録アプリの現在状態が一覧表示される瞬間。
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allApps = ref.watch(sortedConnectedAppsProvider);
    final apps = ref.watch(filteredSortedConnectedAppsProvider);
    final sortOption = ref.watch(dashboardSortOptionProvider);
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
          PopupMenuButton<DashboardSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.dashboardSortLabel,
            initialValue: sortOption,
            onSelected: (value) =>
                ref.read(dashboardSortOptionProvider.notifier).state = value,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: DashboardSortOption.manual,
                checked: sortOption == DashboardSortOption.manual,
                child: Text(l10n.dashboardSortManual),
              ),
              CheckedPopupMenuItem(
                value: DashboardSortOption.nameAsc,
                checked: sortOption == DashboardSortOption.nameAsc,
                child: Text(l10n.dashboardSortName),
              ),
              CheckedPopupMenuItem(
                value: DashboardSortOption.platform,
                checked: sortOption == DashboardSortOption.platform,
                child: Text(l10n.dashboardSortPlatform),
              ),
            ],
          ),
          if (allApps.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: l10n.dashboardExportAllTooltip,
              onPressed: () => context.push('/export-all'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: allApps.isEmpty
          ? _EmptyDashboard(message: l10n.dashboardEmptyMessage)
          : Column(
              children: [
                _SearchAndFilterBar(l10n: l10n),
                Expanded(
                  child: apps.isEmpty
                      ? _EmptyDashboard(message: l10n.dashboardNoMatchMessage)
                      : sortOption == DashboardSortOption.manual
                          ? ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: apps.length,
                              onReorderItem: (oldIndex, newIndex) => ref
                                  .read(connectedAppsProvider.notifier)
                                  .reorder(oldIndex, newIndex),
                              itemBuilder: (context, i) => _AppStatusCard(
                                key: ValueKey(apps[i].id),
                                app: apps[i],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: apps.length,
                              itemBuilder: (context, i) => _AppStatusCard(
                                key: ValueKey(apps[i].id),
                                app: apps[i],
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app-registration'),
        icon: const Icon(Icons.add),
        label: Text(l10n.dashboardAddApp),
      ),
      bottomNavigationBar: plan == UserPlan.free
          ? _AdBannerBar(l10n: l10n)
          : null,
    );
  }
}

/// 無料ユーザー向けのバナー広告表示エリア。「広告を消す」への導線も兼ねる。
class _AdBannerBar extends ConsumerWidget {
  final AppLocalizations l10n;
  const _AdBannerBar({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adBannerBuilder = ref.watch(adBannerWidgetBuilderProvider);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => context.push('/paywall'),
            child: Text(l10n.dashboardRemoveAds),
          ),
          adBannerBuilder(context),
        ],
      ),
    );
  }
}

/// 検索欄 + プラットフォームフィルターのチップ行。
/// アプリが1件以上ある時だけ表示される(空状態では出す意味が無いため)。
class _SearchAndFilterBar extends ConsumerWidget {
  final AppLocalizations l10n;
  const _SearchAndFilterBar({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformFilter = ref.watch(dashboardPlatformFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: l10n.dashboardSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) =>
                ref.read(dashboardSearchQueryProvider.notifier).state = value,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.dashboardFilterAll),
                selected: platformFilter == null,
                onSelected: (_) => ref
                    .read(dashboardPlatformFilterProvider.notifier)
                    .state = null,
              ),
              ChoiceChip(
                label: const Text('iOS'),
                selected: platformFilter == PlatformType.ios,
                onSelected: (_) => ref
                    .read(dashboardPlatformFilterProvider.notifier)
                    .state = PlatformType.ios,
              ),
              ChoiceChip(
                label: const Text('Android'),
                selected: platformFilter == PlatformType.android,
                onSelected: (_) => ref
                    .read(dashboardPlatformFilterProvider.notifier)
                    .state = PlatformType.android,
              ),
            ],
          ),
        ],
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
