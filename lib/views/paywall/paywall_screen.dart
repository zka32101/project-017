import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/user_plan.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';

/// ペイウォール: 3本目のアプリ登録時に表示（アプリ数ゲート、時間ゲートではない。設計書 Step3.5 R④）。
/// 実RevenueCat連携は次フェーズ、MVPはプラン切替のみ。
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

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
              const Icon(Icons.workspace_premium_outlined,
                  size: 64, color: AppTheme.warning),
              const SizedBox(height: 24),
              Text(l10n.paywallTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                l10n.paywallBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // setPlan() 経由にすることでプラン変更も永続化される
                  // （userPlanProvider.notifier.state を直接書き換えると次回起動時に消える）。
                  ref.read(connectedAppsProvider.notifier).setPlan(UserPlan.pro);
                  context.pop();
                  context.push('/app-registration');
                },
                child: Text(l10n.paywallUpgrade),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(l10n.paywallLater,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
