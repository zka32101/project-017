import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_plan.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';

/// ペイウォール: 3本目のアプリ登録時に表示（アプリ数ゲート、時間ゲートではない。設計書 Step3.5 R④）。
/// 実RevenueCat連携は次フェーズ、MVPはプラン切替のみ。
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Text('3本目のアプリを管理するには',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Pro プランでアプリ登録数が無制限になります。\n'
                'プッシュ通知即時化・ウィジェット・チーム共有も利用可能です。\n'
                '¥600/月 または ¥5,000/年',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  ref.read(userPlanProvider.notifier).state = UserPlan.pro;
                  context.pop();
                  context.push('/app-registration');
                },
                child: const Text('Pro にアップグレード'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('あとで', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
