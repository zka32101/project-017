import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_plan.dart';
import '../../viewmodels/connected_apps_notifier.dart';

/// 設定: APIキー管理・通知設定・サブスク管理（設計書 Step2）。MVPは基本項目のみ。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(connectedAppsProvider);
    final plan = ref.watch(userPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('プラン'),
            subtitle: Text(plan == UserPlan.pro ? 'Pro（無制限）' : 'Free（2アプリまで）'),
          ),
          const Divider(),
          ListTile(
            title: const Text('登録アプリ管理'),
            subtitle: Text('${apps.length}件登録中'),
          ),
          for (final app in apps)
            ListTile(
              dense: true,
              title: Text(app.displayName),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(connectedAppsProvider.notifier).removeApp(app.id),
              ),
            ),
          const Divider(),
          const ListTile(
            title: Text('通知設定'),
            subtitle: Text('毎朝の状態サマリー通知（未実装・次フェーズ）'),
          ),
        ],
      ),
    );
  }
}
