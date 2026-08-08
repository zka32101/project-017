import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/initial_scan_provider.dart';

/// 初回スキャン: 自動（設計書 Step2）。APIキー入力後は自動実行、ユーザー待機のみ。
/// 完了後、Aha Momentであるダッシュボードへ自動遷移する。
class InitialScanScreen extends ConsumerWidget {
  const InitialScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const Text('登録したアプリの状態を確認しています…'),
            const SizedBox(height: 8),
            const Text(
              '管制塔が起動しています',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (scan.hasError) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('ダッシュボードへ進む'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
