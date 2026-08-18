import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/service_providers.dart';

/// 通知許可プレプロンプト。区分: ユーザー作業（1タップ）、以降は自動（設計書 Step2 表）。
/// OS標準ダイアログの前に価値を説明し、拒否率を下げる（プレプロンプトパターン）。
/// 「通知を許可する」タップで実際にOSの許可ダイアログをリクエストし、許可されれば
/// 毎朝のリマインダーをスケジュールする(NotificationService参照)。
/// 許可の可否に関わらず、この画面自体は常に次(アプリ登録)へ進む
/// （通知が使えなくてもアプリの主要機能は使えるため、ここでブロックしない）。
class NotificationPrePromptScreen extends ConsumerWidget {
  const NotificationPrePromptScreen({super.key});

  Future<void> _allow(WidgetRef ref, BuildContext context) async {
    final notificationService = ref.read(notificationServiceProvider);
    final secureStorage = ref.read(secureStorageServiceProvider);
    final granted = await notificationService.requestPermission();
    if (granted) {
      await notificationService.scheduleDailyReminder();
      await secureStorage.writeValue(
        key: notificationsEnabledStorageKey,
        value: 'true',
      );
    }
    if (context.mounted) context.go('/app-registration');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => _allow(ref, context),
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
