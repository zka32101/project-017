import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
import '../../models/connected_app.dart';
import '../../models/platform_type.dart';
import '../../models/user_plan.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_review_management_notifier.dart';
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
    final selectionMode = ref.watch(dashboardSelectionModeProvider);
    final selectedIds = ref.watch(dashboardSelectedAppIdsProvider);
    // ホーム画面ウィジェット用データを常に最新化する（Should機能の土台、失敗しても画面表示は継続）。
    ref.watch(widgetSyncProvider);

    // 起動時に一度だけ、永続化データの復元 or デモアプリの自動投入を行う
    // （オンボーディング→アプリ登録フロー不要で、直接ダッシュボードからテスト開始可能）。
    // AsyncValueは使わずbareでwatchするだけなので、失敗してもこの画面自体は
    // クラッシュしない（appsが空のままなら _EmptyDashboard が表示される）。
    ref.watch(appBootstrapProvider);
    // 前回終了時のフィルター/ソート条件を復元する(初回のみ、同じくbareにwatch)。
    ref.watch(dashboardFilterPrefsBootstrapProvider);

    void exitSelectionMode() {
      ref.read(dashboardSelectionModeProvider.notifier).state = false;
      ref.read(dashboardSelectedAppIdsProvider.notifier).state = {};
    }

    Future<void> confirmBulkDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.dashboardBulkDeleteConfirmTitle(selectedIds.length)),
          content: Text(l10n.dashboardBulkDeleteConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(connectedAppsProvider.notifier).removeApps(selectedIds);
      exitSelectionMode();
    }

    Future<void> openBulkTagEdit() async {
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _BulkTagEditDialog(l10n: l10n, appIds: selectedIds),
      );
    }

    return Scaffold(
      appBar: selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: exitSelectionMode,
              ),
              title: Text(l10n.dashboardSelectedCount(selectedIds.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.label_outline),
                  tooltip: l10n.dashboardBulkTagEditTooltip,
                  onPressed: selectedIds.isEmpty ? null : openBulkTagEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.dashboardBulkDeleteTooltip,
                  onPressed: selectedIds.isEmpty ? null : confirmBulkDelete,
                ),
              ],
            )
          : AppBar(
              title: Text(l10n.appTitle),
              actions: [
                if (allApps.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist_outlined),
                    tooltip: l10n.dashboardSelectModeTooltip,
                    onPressed: () => ref
                        .read(dashboardSelectionModeProvider.notifier)
                        .state = true,
                  ),
                PopupMenuButton<DashboardSortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: l10n.dashboardSortLabel,
                  initialValue: sortOption,
                  onSelected: (value) {
                    ref.read(dashboardSortOptionProvider.notifier).state = value;
                    saveDashboardFilterPrefs(ref);
                  },
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
                      // 選択モード中はドラッグ並び替えと選択タップの操作が競合するため、
                      // manualソートでも常にListView(ドラッグ無効)にする。
                      : !selectionMode && sortOption == DashboardSortOption.manual
                          ? ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: apps.length,
                              onReorderItem: (oldIndex, newIndex) => ref
                                  .read(connectedAppsProvider.notifier)
                                  .reorder(oldIndex, newIndex),
                              itemBuilder: (context, i) => _AppStatusCard(
                                key: ValueKey(apps[i].id),
                                app: apps[i],
                                selectionMode: selectionMode,
                                selected: selectedIds.contains(apps[i].id),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: apps.length,
                              itemBuilder: (context, i) => _AppStatusCard(
                                key: ValueKey(apps[i].id),
                                app: apps[i],
                                selectionMode: selectionMode,
                                selected: selectedIds.contains(apps[i].id),
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
    final attentionOnly = ref.watch(dashboardAttentionOnlyProvider);
    final attentionCount = ref.watch(dashboardAttentionCountProvider);
    final tagFilter = ref.watch(dashboardTagFilterProvider);
    final allTags = ref.watch(allTagsProvider);

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
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.dashboardFilterAll),
                selected: platformFilter == null,
                onSelected: (_) {
                  ref.read(dashboardPlatformFilterProvider.notifier).state = null;
                  saveDashboardFilterPrefs(ref);
                },
              ),
              ChoiceChip(
                label: const Text('iOS'),
                selected: platformFilter == PlatformType.ios,
                onSelected: (_) {
                  ref.read(dashboardPlatformFilterProvider.notifier).state =
                      PlatformType.ios;
                  saveDashboardFilterPrefs(ref);
                },
              ),
              ChoiceChip(
                label: const Text('Android'),
                selected: platformFilter == PlatformType.android,
                onSelected: (_) {
                  ref.read(dashboardPlatformFilterProvider.notifier).state =
                      PlatformType.android;
                  saveDashboardFilterPrefs(ref);
                },
              ),
              ChoiceChip(
                label: Text(l10n.dashboardAttentionFilter(attentionCount)),
                avatar: attentionOnly
                    ? null
                    : const Icon(Icons.error_outline, size: 18, color: AppTheme.danger),
                selected: attentionOnly,
                onSelected: (value) {
                  ref.read(dashboardAttentionOnlyProvider.notifier).state = value;
                  saveDashboardFilterPrefs(ref);
                },
              ),
            ],
          ),
          // タグが1つも登録されていない場合は行自体を出さない(絞り込む対象が無いため)。
          if (allTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in allTags)
                  ChoiceChip(
                    label: Text(tag),
                    selected: tagFilter == tag,
                    onSelected: (selected) {
                      ref.read(dashboardTagFilterProvider.notifier).state =
                          selected ? tag : null;
                      saveDashboardFilterPrefs(ref);
                    },
                  ),
              ],
            ),
          ],
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
  final bool selectionMode;
  final bool selected;
  const _AppStatusCard({
    super.key,
    required this.app,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statusAsync = ref.watch(latestReviewStatusProvider(app));
    // 管理タブ(app_detail_screen.dart)で設定した手動ステータス上書きの
    // 復元(初回のみ)。checklist_screen.dart等と同じパターンでbareにwatch。
    ref.watch(appReviewManagementBootstrapProvider(app.id));
    final manualOverride =
        ref.watch(appReviewManagementProvider(app.id)).manualStatusOverride;

    void toggleSelected() {
      final current = ref.read(dashboardSelectedAppIdsProvider);
      ref.read(dashboardSelectedAppIdsProvider.notifier).state = selected
          ? (current.toSet()..remove(app.id))
          : (current.toSet()..add(app.id));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: selectionMode
            ? toggleSelected
            : () => context.push('/app-detail/${app.id}', extra: app),
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => toggleSelected(),
              )
            : CircleAvatar(
                backgroundColor: AppTheme.surfaceVariant,
                child: Text(app.platform == PlatformType.ios ? 'iOS' : 'And',
                    style: const TextStyle(fontSize: 10)),
              ),
        title: Text(app.displayName),
        subtitle: statusAsync.when(
          data: (s) {
            final status = manualOverride ?? s?.statusType;
            if (status == null) return Text(l10n.dashboardStatusUnknown);
            final label = status.label(l10n);
            final text = s == null ? label : '${s.versionString} ・ $label';
            return Text(manualOverride != null
                ? l10n.dashboardManualStatusSuffix(text)
                : text);
          },
          loading: () => Text(l10n.dashboardStatusLoading),
          error: (e, _) => manualOverride == null
              ? Text(localizedErrorMessage(l10n, e),
                  maxLines: 1, overflow: TextOverflow.ellipsis)
              : Text(l10n.dashboardManualStatusSuffix(manualOverride.label(l10n))),
        ),
        trailing: statusAsync.when(
          data: (s) {
            final status = manualOverride ?? s?.statusType;
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == null
                    ? AppTheme.textSecondary
                    : AppTheme.colorForStatus(status),
              ),
            );
          },
          loading: () => const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => manualOverride != null
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.colorForStatus(manualOverride),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppTheme.danger),
                  tooltip: l10n.commonRetry,
                  onPressed: () => ref.invalidate(latestReviewStatusProvider(app)),
                ),
        ),
      ),
    );
  }
}

/// 選択中の複数アプリへまとめてタグを追加・削除するダイアログ
/// (ダッシュボードの一括選択モードから開く、大量アプリ管理用のタグ一括編集機能)。
/// 各操作はすぐにConnectedAppsNotifier側へ反映される(送信ボタンで確定する
/// 設計ではない)ため、閉じるボタンに「キャンセル」の意味は無い。
class _BulkTagEditDialog extends ConsumerStatefulWidget {
  final AppLocalizations l10n;
  final Set<String> appIds;
  const _BulkTagEditDialog({required this.l10n, required this.appIds});

  @override
  ConsumerState<_BulkTagEditDialog> createState() => _BulkTagEditDialogState();
}

class _BulkTagEditDialogState extends ConsumerState<_BulkTagEditDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String value) {
    final tag = value.trim();
    _controller.clear();
    if (tag.isEmpty) return;
    ref.read(connectedAppsProvider.notifier).addTagToApps(widget.appIds, tag);
  }

  @override
  Widget build(BuildContext context) {
    // 選択中のアプリのうち、いずれか1つでも持っているタグを削除候補として
    // 一覧表示する(全員が同じタグを持っているとは限らないため、「持っている
    // アプリからだけ取り除く」動作になる。removeTagFromApps参照)。
    final apps = ref.watch(connectedAppsProvider);
    final tagsInSelection = apps
        .where((a) => widget.appIds.contains(a.id))
        .expand((a) => a.tags)
        .toSet()
        .toList()
      ..sort();

    return AlertDialog(
      title: Text(widget.l10n.dashboardBulkTagEditTitle(widget.appIds.length)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tagsInSelection.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tagsInSelection)
                    Chip(
                      label: Text(tag),
                      onDeleted: () => ref
                          .read(connectedAppsProvider.notifier)
                          .removeTagFromApps(widget.appIds, tag),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('bulkTagsInput'),
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.l10n.appDetailManagementTagsHint,
                isDense: true,
              ),
              onSubmitted: _addTag,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.commonClose),
        ),
      ],
    );
  }
}
