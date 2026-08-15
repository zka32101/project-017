import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/initial_scan_provider.dart';

/// 初回スキャン: 自動（設計書 Step2）。APIキー入力後は自動実行、ユーザー待機のみ。
/// 完了後、Aha Momentであるダッシュボードへ自動遷移する。
class InitialScanScreen extends ConsumerWidget {
  const InitialScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scan = ref.watch(initialScanProvider);

    ref.listen(initialScanProvider, (prev, next) {
      if (next is AsyncData) {
        context.go('/dashboard');
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 24),
            Text(l10n.initialScanMessage),
            const SizedBox(height: 8),
            Text(
              l10n.initialScanSubMessage,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (scan.hasError) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: Text(l10n.initialScanProceedAnyway),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
