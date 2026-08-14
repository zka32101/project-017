import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connected_app.dart';
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
          for (final app in apps) _AppSettingsTile(app: app),
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

/// 削除操作を独立してローディング/エラー表示できるよう、行単位でStateを持たせる。
/// removeApp は Secure Storage の削除を伴うため失敗し得るが、以前は結果を
/// 待たずに投げっぱなしにしていたため、失敗時に無反応のまま何も起きなかった。
class _AppSettingsTile extends ConsumerStatefulWidget {
  final ConnectedApp app;
  const _AppSettingsTile({required this.app});

  @override
  ConsumerState<_AppSettingsTile> createState() => _AppSettingsTileState();
}

class _AppSettingsTileState extends ConsumerState<_AppSettingsTile> {
  bool _removing = false;

  Future<void> _remove() async {
    setState(() => _removing = true);
    try {
      await ref.read(connectedAppsProvider.notifier).removeApp(widget.app.id);
      // 成功時は state からアプリが消えるため、この Widget 自体が破棄される
      // （setState は不要、かつ破棄後のsetStateはエラーになるため呼ばない）。
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(widget.app.displayName),
      trailing: _removing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _remove,
            ),
    );
  }
}
