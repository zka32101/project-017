import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
import '../../models/app_review_management.dart';
import '../../models/build_failure_log.dart';
import '../../models/connected_app.dart';
import '../../models/crash_summary.dart';
import '../../models/rejection_detail.dart';
import '../../models/review_status_snapshot.dart';
import '../../models/review_status_type.dart';
import '../../models/revenue_summary.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_detail_providers.dart';
import '../../viewmodels/app_review_management_notifier.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/dashboard_providers.dart';

/// アプリ詳細: 審査履歴/クラッシュ推移/売上・DL数/リジェクト理由/ビルド失敗ログ/管理の6タブ
/// （Must#1拡張＋Should機能の売上サマリー・管理項目）。
/// initialTabIndexで初期表示タブを指定できる(設計書Step2の「リジェクト通知
/// タップでリジェクト理由タブを開く」導線に対応。router/app_router.dartの
/// `/app-detail/:id` がクエリパラメータ`tab`(タブのindex)から解決し、
/// NotificationService.showReviewStatusChangedNotification が
/// リジェクト時にそのクエリ付きpayloadを設定する)。
class AppDetailScreen extends ConsumerStatefulWidget {
  final ConnectedApp app;
  final int initialTabIndex;
  const AppDetailScreen({super.key, required this.app, this.initialTabIndex = 0});

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text(app.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: l10n.appDetailExportTooltip,
            onPressed: () => context.push('/export/${app.id}', extra: app),
          ),
          IconButton(
            icon: const Icon(Icons.checklist_outlined),
            tooltip: l10n.appDetailChecklistTooltip,
            onPressed: () =>
                context.push('/checklist/${app.id}', extra: app),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.appDetailTabReviewHistory),
            Tab(text: l10n.appDetailTabCrashTrend),
            Tab(text: l10n.appDetailTabRevenue),
            Tab(text: l10n.appDetailTabRejection),
            Tab(text: l10n.appDetailTabBuildFailure),
            Tab(text: l10n.appDetailTabManagement),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReviewHistoryTab(app: app),
          _CrashTrendTab(app: app),
          _RevenueTab(app: app),
          _RejectionTab(app: app),
          _BuildFailureTab(app: app),
          _ManagementTab(app: app),
        ],
      ),
    );
  }
}

/// AsyncValue&lt;List&lt;T&gt;&gt;を受け取り、loading/error/empty/dataの4状態を
/// まとめて表示する共通タブWidget。アプリ詳細画面の5タブが同じ
/// `.when(loading: ..., error: ..., data: (items) => items.isEmpty ? ... : ...)`
/// を個別に書いていたため、可変部分(プロバイダの参照・空メッセージ・非空時の
/// 表示)だけを引数として受け取る形にまとめてある。
class _AsyncListTab<T> extends ConsumerWidget {
  final AsyncValue<List<T>> Function(WidgetRef ref) watch;
  final void Function(WidgetRef ref) invalidate;
  final String Function(AppLocalizations l10n) emptyMessage;
  final Widget Function(BuildContext context, AppLocalizations l10n, List<T> items)
      dataBuilder;

  const _AsyncListTab({
    required this.watch,
    required this.invalidate,
    required this.emptyMessage,
    required this.dataBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return watch(ref).when(
      data: (items) => items.isEmpty
          ? _EmptyTab(message: emptyMessage(l10n))
          : dataBuilder(context, l10n, items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(error: e, onRetry: () => invalidate(ref)),
    );
  }
}

class _ReviewHistoryTab extends ConsumerWidget {
  final ConnectedApp app;
  const _ReviewHistoryTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncListTab<ReviewStatusSnapshot>(
      watch: (ref) => ref.watch(reviewHistoryProvider(app)),
      invalidate: (ref) => ref.invalidate(reviewHistoryProvider(app)),
      emptyMessage: (l10n) => l10n.appDetailReviewHistoryEmpty,
      dataBuilder: (context, l10n, items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final s = items[i];
          return Card(
            child: ListTile(
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.colorForStatus(s.statusType),
                ),
              ),
              title: Text('v${s.versionString}'),
              subtitle: Text(s.statusType.label(l10n)),
              trailing: Text(
                '${s.fetchedAt.month}/${s.fetchedAt.day}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrashTrendTab extends ConsumerWidget {
  final ConnectedApp app;
  const _CrashTrendTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncListTab<CrashSummary>(
      watch: (ref) => ref.watch(crashSummariesProvider(app)),
      invalidate: (ref) => ref.invalidate(crashSummariesProvider(app)),
      emptyMessage: (l10n) => l10n.appDetailCrashDataEmpty,
      dataBuilder: (context, l10n, items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final c = items[i];
          return ListTile(
            leading: Icon(
              c.isSpiking() ? Icons.warning_amber : Icons.check_circle_outline,
              color: c.isSpiking() ? AppTheme.danger : AppTheme.primary,
            ),
            title: Text('${c.date.month}/${c.date.day}'),
            subtitle: Text(l10n.appDetailCrashFreeRate(
                c.crashFreeRate.toStringAsFixed(1), c.crashCount)),
          );
        },
      ),
    );
  }
}

class _RevenueTab extends ConsumerWidget {
  final ConnectedApp app;
  const _RevenueTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncListTab<RevenueSummary>(
      watch: (ref) => ref.watch(revenueSummaryProvider(app)),
      invalidate: (ref) => ref.invalidate(revenueSummaryProvider(app)),
      emptyMessage: (l10n) => l10n.appDetailRevenueEmpty,
      dataBuilder: (context, l10n, items) => _RevenueList(items: items),
    );
  }
}

class _RevenueList extends StatelessWidget {
  final List<RevenueSummary> items;
  const _RevenueList({required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalRevenue = items.fold<double>(0, (sum, r) => sum + r.revenue);
    final totalDownloads = items.fold<int>(0, (sum, r) => sum + r.downloadCount);
    final currency = items.first.currencyCode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: l10n.appDetailRevenueSummaryLabel(items.length),
                  value: '$currency ${totalRevenue.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  label: l10n.appDetailDownloadsTotalLabel,
                  value: '$totalDownloads',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[items.length - 1 - i]; // 新しい日付を上に
              return ListTile(
                dense: true,
                title: Text('${r.date.month}/${r.date.day}'),
                trailing: Text(
                  l10n.appDetailRevenueRow(
                      currency, r.revenue.toStringAsFixed(0), r.downloadCount),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RejectionTab extends ConsumerWidget {
  final ConnectedApp app;
  const _RejectionTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncListTab<RejectionDetail>(
      watch: (ref) => ref.watch(rejectionDetailsProvider(app)),
      invalidate: (ref) => ref.invalidate(rejectionDetailsProvider(app)),
      emptyMessage: (l10n) => l10n.appDetailRejectionEmpty,
      dataBuilder: (context, l10n, items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final r = items[i];
          return Card(
            child: ListTile(
              title: Text(r.guidelineTitle ??
                  r.guidelineNumber ??
                  l10n.appDetailRejectionUnknownReason),
              subtitle: Text(r.resolutionCenterMessage),
            ),
          );
        },
      ),
    );
  }
}

class _BuildFailureTab extends ConsumerWidget {
  final ConnectedApp app;
  const _BuildFailureTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncListTab<BuildFailureLog>(
      watch: (ref) => ref.watch(buildFailureLogsProvider(app)),
      invalidate: (ref) => ref.invalidate(buildFailureLogsProvider(app)),
      emptyMessage: (l10n) => l10n.appDetailBuildFailureEmpty,
      dataBuilder: (context, l10n, items) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final b = items[i];
          return Card(
            child: ListTile(
              title: Text(l10n.appDetailBuildNumber(b.buildNumber)),
              subtitle: Text(b.failureReason),
            ),
          );
        },
      ),
    );
  }
}

/// 管理タブ: 審査状態の手動上書き・審査提出日/審査開始日・メモ（対応履歴）。
/// AppReviewManagementのドキュメントコメント参照。
class _ManagementTab extends ConsumerStatefulWidget {
  final ConnectedApp app;
  const _ManagementTab({required this.app});

  @override
  ConsumerState<_ManagementTab> createState() => _ManagementTabState();
}

class _ManagementTabState extends ConsumerState<_ManagementTab> {
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_onNoteFocusChange);
  }

  void _onNoteFocusChange() {
    if (!_noteFocusNode.hasFocus) {
      ref
          .read(appReviewManagementProvider(widget.app.id).notifier)
          .setNote(_noteController.text);
    }
  }

  @override
  void dispose() {
    _noteFocusNode.removeListener(_onNoteFocusChange);
    _noteFocusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appId = widget.app.id;

    // 永続化データの復元(初回のみ)。checklist_screen.dartと同じパターンで
    // bareにwatchする(復元完了を明示的に待つ必要は無く、失敗してもこの
    // タブ自体はクラッシュしない)。
    ref.watch(appReviewManagementBootstrapProvider(appId));

    // ノート欄はTextEditingControllerで自前管理しているため、復元完了時
    // (build()の外でnotifier.restore()が呼ばれた時)だけテキストを同期する。
    // 毎キー入力でstateへ書き込む設計ではない(setNoteはフォーカスが外れた
    // 時にしか呼ばれない)ため、ユーザー入力中にこのlistenがカーソル位置を
    // リセットすることは無い。
    ref.listen<AppReviewManagement>(
      appReviewManagementProvider(appId),
      (previous, next) {
        if (_noteController.text != next.note) {
          _noteController.text = next.note;
        }
      },
    );

    final management = ref.watch(appReviewManagementProvider(appId));
    final autoStatus = ref.watch(latestReviewStatusProvider(widget.app));
    final notifier = ref.read(appReviewManagementProvider(appId).notifier);

    // タグはConnectedApp側のフィールドなので、widget.app(遷移時に渡された
    // 静的なスナップショット)ではなく、connectedAppsProviderを都度watchして
    // 編集直後の最新値を表示する。
    final apps = ref.watch(connectedAppsProvider);
    final liveApp = apps.cast<ConnectedApp?>().firstWhere(
          (a) => a?.id == appId,
          orElse: () => null,
        ) ??
        widget.app;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ManualStatusCard(
          l10n: l10n,
          autoStatus: autoStatus,
          management: management,
          onChanged: notifier.setManualStatusOverride,
        ),
        const SizedBox(height: 16),
        _DateManagementCard(
          l10n: l10n,
          management: management,
          onSubmittedAtChanged: notifier.setSubmittedAt,
          onReviewStartedAtChanged: notifier.setReviewStartedAt,
        ),
        const SizedBox(height: 16),
        _TagsCard(
          l10n: l10n,
          tags: liveApp.tags,
          onChanged: (tags) => ref
              .read(connectedAppsProvider.notifier)
              .setTags(appId, tags),
        ),
        const SizedBox(height: 16),
        _NoteCard(
          l10n: l10n,
          controller: _noteController,
          focusNode: _noteFocusNode,
        ),
      ],
    );
  }
}

class _ManualStatusCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<ReviewStatusSnapshot?> autoStatus;
  final AppReviewManagement management;
  final ValueChanged<ReviewStatusType?> onChanged;

  const _ManualStatusCard({
    required this.l10n,
    required this.autoStatus,
    required this.management,
    required this.onChanged,
  });

  String get _autoStatusLabel => autoStatus.when(
        data: (s) =>
            s == null ? l10n.dashboardStatusUnknown : s.statusType.label(l10n),
        loading: () => l10n.dashboardStatusLoading,
        error: (_, _) => l10n.dashboardStatusUnknown,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appDetailManagementStatusSectionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              l10n.appDetailManagementAutoStatusValue(_autoStatusLabel),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // 手動上書きが外部要因(次回自動取得の成功時のクリア・復元完了)で
            // 変わった場合、DropdownButtonFormFieldのinitialValueは初回構築時
            // にしか反映されない(FormFieldの仕様)ため、値が変わるたびにkeyを
            // 変えてウィジェット自体を作り直し、表示を確実に同期させる。
            DropdownButtonFormField<ReviewStatusType?>(
              key: ValueKey(management.manualStatusOverride),
              initialValue: management.manualStatusOverride,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.appDetailManagementManualStatusLabel,
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  child: Text(l10n.appDetailManagementAutoOption),
                ),
                for (final type in ReviewStatusType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.label(l10n)),
                  ),
              ],
              onChanged: onChanged,
            ),
            if (management.manualStatusOverride != null) ...[
              const SizedBox(height: 8),
              Text(l10n.appDetailManagementManualOverrideHint,
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateManagementCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AppReviewManagement management;
  final ValueChanged<DateTime?> onSubmittedAtChanged;
  final ValueChanged<DateTime?> onReviewStartedAtChanged;

  const _DateManagementCard({
    required this.l10n,
    required this.management,
    required this.onSubmittedAtChanged,
    required this.onReviewStartedAtChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appDetailManagementDatesLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _DateRow(
              label: l10n.appDetailManagementSubmittedAtLabel,
              value: management.submittedAt,
              onChanged: onSubmittedAtChanged,
            ),
            const Divider(height: 24),
            _DateRow(
              label: l10n.appDetailManagementReviewStartedAtLabel,
              value: management.reviewStartedAt,
              onChanged: onReviewStartedAtChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = value;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(date == null
                  ? l10n.appDetailManagementDateNotSet
                  : '${date.year}/${date.month}/${date.day}'),
            ],
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            tooltip: l10n.appDetailManagementClearDate,
            onPressed: () => onChanged(null),
          ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(l10n.commonSelect),
        ),
      ],
    );
  }
}

/// タグ編集(大量アプリ管理用)。フリーテキストで入力してEnterで追加、
/// 各タグはChipのバツ印で削除する。入力欄自体は保存対象の状態を
/// 持たないため(送信済みタグはConnectedApp.tags側が真実)、
/// controllerはこのWidget内で完結させて良い(_NoteCardのように
/// 外部からの復元同期は不要)。
class _TagsCard extends StatefulWidget {
  final AppLocalizations l10n;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  const _TagsCard({
    required this.l10n,
    required this.tags,
    required this.onChanged,
  });

  @override
  State<_TagsCard> createState() => _TagsCardState();
}

class _TagsCardState extends State<_TagsCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String value) {
    final tag = value.trim();
    _controller.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
  }

  void _removeTag(String tag) =>
      widget.onChanged(widget.tags.where((t) => t != tag).toList());

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.l10n.appDetailManagementTagsLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (widget.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.tags)
                    Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const Key('tagsInput'),
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
    );
  }
}

class _NoteCard extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _NoteCard({
    required this.l10n,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appDetailManagementNoteLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: l10n.appDetailManagementNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String message;
  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

/// 通信失敗時の表示。ServiceFailure が例外として伝播するようになったことで、
/// 「データが本当に無い」（_EmptyTab）と区別して原因メッセージ＋再試行を出せる。
class _ErrorTab extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorTab({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 32),
            const SizedBox(height: 12),
            Text(localizedErrorMessage(l10n, error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
