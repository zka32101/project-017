import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/service_failure_l10n.dart';
import '../../models/connected_app.dart';
import '../../models/export_job.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/export_provider.dart';

/// レポートエクスポート（Should機能）: 審査履歴・リジェクト理由・ビルド失敗ログをPDF/CSVで出力。
/// 審査対応の記録保存・外注先共有等の用途を想定（設計書 Step3）。
/// app=nullの場合は「全アプリ集約エクスポート」モードになり、その時点の
/// 登録アプリ全件をまとめて1つのファイルに出力する（ダッシュボードの
/// エクスポートアイコンから遷移、/export-allルート）。
class ExportScreen extends ConsumerStatefulWidget {
  final ConnectedApp? app;
  const ExportScreen({super.key, this.app});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.pdf;

  @override
  void initState() {
    super.initState();
    // 画面を出入りするたびに前回の結果を引きずらないようリセットする。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exportProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exportState = ref.watch(exportProvider);
    final app = widget.app;
    final isAllApps = app == null;
    // 全アプリ集約モードでは、生成ボタンを押した時点の登録アプリ一覧をそのまま使う。
    final allApps =
        isAllApps ? ref.watch(connectedAppsProvider) : const <ConnectedApp>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(isAllApps ? l10n.exportAllTitle : l10n.exportTitle(app.displayName)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAllApps ? l10n.exportAllDescription : l10n.exportDescription,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            SegmentedButton<ExportFormat>(
              segments: const [
                ButtonSegment(value: ExportFormat.pdf, label: Text('PDF')),
                ButtonSegment(value: ExportFormat.csv, label: Text('CSV')),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: exportState is AsyncLoading ||
                      (isAllApps && allApps.isEmpty)
                  ? null
                  : () => isAllApps
                      ? ref.read(exportProvider.notifier).runExportAll(
                            apps: allApps,
                            format: _format,
                          )
                      : ref.read(exportProvider.notifier).runExport(
                            app: app,
                            format: _format,
                          ),
              child: exportState is AsyncLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.exportGenerate),
            ),
            const SizedBox(height: 20),
            if (exportState != null) _ExportResult(state: exportState),
          ],
        ),
      ),
    );
  }
}

class _ExportResult extends StatelessWidget {
  final AsyncValue<ExportJob> state;
  const _ExportResult({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(
          l10n.exportFailedWithReason(localizedErrorMessage(l10n, e)),
          style: const TextStyle(color: AppTheme.danger)),
      data: (job) {
        if (job.status == ExportJobStatus.failed) {
          return Text(l10n.exportFailed,
              style: const TextStyle(color: AppTheme.danger));
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.exportGenerated(job.format.name.toUpperCase())),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.exportExpiresAt(
                      job.expiresAt?.toLocal().toString().substring(0, 16) ?? '-'),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.exportShare),
                  onPressed: job.fileUrl == null
                      ? null
                      : () => Share.shareXFiles([XFile(job.fileUrl!)]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
