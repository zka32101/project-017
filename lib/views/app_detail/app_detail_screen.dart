import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connected_app.dart';
import '../../models/revenue_summary.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_detail_providers.dart';

/// アプリ詳細: 審査履歴/クラッシュ推移/売上・DL数/リジェクト理由/ビルド失敗ログの5タブ
/// （Must#1拡張＋Should機能の売上サマリー）。
/// 通知タップからのディープリンクでは、リジェクト通知の場合はリジェクト理由タブを開いた状態で表示する
/// （設計書 Step2）— initialTabIndex で制御。
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
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text(app.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'エクスポート',
            onPressed: () => context.push('/export/${app.id}', extra: app),
          ),
          IconButton(
            icon: const Icon(Icons.checklist_outlined),
            tooltip: '提出前チェックリスト',
            onPressed: () =>
                context.push('/checklist/${app.id}', extra: app),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '審査履歴'),
            Tab(text: 'クラッシュ推移'),
            Tab(text: '売上・DL数'),
            Tab(text: 'リジェクト理由'),
            Tab(text: 'ビルド失敗ログ'),
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

class _ReviewHistoryTab extends ConsumerWidget {
  final ConnectedApp app;
  const _ReviewHistoryTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reviewHistoryProvider(app));
    return history.when(
      data: (items) => items.isEmpty
          ? const _EmptyTab(message: '審査履歴はまだありません')
          : ListView.builder(
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
                        color: AppTheme.colorForStatusKey(s.statusType.name),
                      ),
                    ),
                    title: Text('v${s.versionString}'),
                    subtitle: Text(s.statusType.label),
                    trailing: Text(
                      '${s.fetchedAt.month}/${s.fetchedAt.day}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(
        error: e,
        onRetry: () => ref.invalidate(reviewHistoryProvider(app)),
      ),
    );
  }
}

class _CrashTrendTab extends ConsumerWidget {
  final ConnectedApp app;
  const _CrashTrendTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crashes = ref.watch(crashSummariesProvider(app));
    return crashes.when(
      data: (items) => items.isEmpty
          ? const _EmptyTab(message: 'クラッシュデータはまだありません')
          : ListView.builder(
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
                  subtitle: Text('クラッシュフリー率 ${c.crashFreeRate.toStringAsFixed(1)}% ・ ${c.crashCount}件'),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(
        error: e,
        onRetry: () => ref.invalidate(crashSummariesProvider(app)),
      ),
    );
  }
}

class _RevenueTab extends ConsumerWidget {
  final ConnectedApp app;
  const _RevenueTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(revenueSummaryProvider(app));
    return revenue.when(
      data: (items) => items.isEmpty
          ? const _EmptyTab(message: '売上データはまだありません')
          : _RevenueList(items: items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(
        error: e,
        onRetry: () => ref.invalidate(revenueSummaryProvider(app)),
      ),
    );
  }
}

class _RevenueList extends StatelessWidget {
  final List<RevenueSummary> items;
  const _RevenueList({required this.items});

  @override
  Widget build(BuildContext context) {
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
                  label: '直近${items.length}日 売上',
                  value: '$currency ${totalRevenue.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  label: 'DL数合計',
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
                  '$currency ${r.revenue.toStringAsFixed(0)} ・ ${r.downloadCount}DL',
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
    final rejections = ref.watch(rejectionDetailsProvider(app));
    return rejections.when(
      data: (items) => items.isEmpty
          ? const _EmptyTab(message: 'リジェクト履歴はありません')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                return Card(
                  child: ListTile(
                    title: Text(r.guidelineTitle ?? r.guidelineNumber ?? '理由不明'),
                    subtitle: Text(r.resolutionCenterMessage),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(
        error: e,
        onRetry: () => ref.invalidate(rejectionDetailsProvider(app)),
      ),
    );
  }
}

class _BuildFailureTab extends ConsumerWidget {
  final ConnectedApp app;
  const _BuildFailureTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(buildFailureLogsProvider(app));
    return logs.when(
      data: (items) => items.isEmpty
          ? const _EmptyTab(message: 'ビルド失敗ログはありません')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final b = items[i];
                return Card(
                  child: ListTile(
                    title: Text('Build ${b.buildNumber}'),
                    subtitle: Text(b.failureReason),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTab(
        error: e,
        onRetry: () => ref.invalidate(buildFailureLogsProvider(app)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 32),
            const SizedBox(height: 12),
            Text('$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}
