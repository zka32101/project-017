import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 通知許可プレプロンプト。区分: ユーザー作業（1タップ）、以降は自動（設計書 Step2 表）。
/// OS標準ダイアログの前に価値を説明し、拒否率を下げる（プレプロンプトパターン）。
class NotificationPrePromptScreen extends StatelessWidget {
  const NotificationPrePromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.notifications_active, size: 64, color: AppTheme.warning),
              const SizedBox(height: 24),
              Text(
                l10n.notificationPromptTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.notificationPromptBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/app-registration'),
                child: Text(l10n.notificationPromptAllow),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/app-registration'),
                child: Text(l10n.notificationPromptLater,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
