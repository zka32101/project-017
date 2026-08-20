import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
import '../../models/build_failure_log.dart';
import '../../models/connected_app.dart';
import '../../models/crash_summary.dart';
import '../../models/rejection_detail.dart';
import '../../models/review_status_snapshot.dart';
import '../../models/revenue_summary.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_detail_providers.dart';

/// アプリ詳細: 審査履歴/クラッシュ推移/売上・DL数/リジェクト理由/ビルド失敗ログの5タブ
/// （Must#1拡張＋Should機能の売上サマリー）。
/// initialTabIndexで初期表示タブを指定できる(設計書Step2は「リジェクト通知
/// タップでリジェクト理由タブを開く」導線を想定しているが、現状の
/// NotificationService はタップ時のハンドラを持たない固定文言の毎朝リマインダー
/// のみで、審査状態変化に連動した個別通知自体が無い。そのためinitialTabIndex
/// は現状どの呼び出し元からも0(デフォルト)以外を渡されておらず未使用。
/// 個別通知の実装時にこのパラメータを活用する想定)。
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
      length: 5,
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
