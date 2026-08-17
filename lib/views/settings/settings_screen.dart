import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/connected_app.dart';
import '../../models/user_plan.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/service_providers.dart';

/// 保存済みAPIキーの一部だけを見せる表示用マスク処理。
/// 全文表示は流出リスクがあるため行わず、かつ末尾4文字だけ見せることで
/// 「ちゃんと登録されているか」をユーザー自身が確認できるようにする。
/// 先頭の伏字部分はキーの実際の長さに関わらず固定幅にする
/// (Android向けサービスアカウントJSONキーは数千文字になり得るため、
/// 実際の長さ分だけ伏字を並べると表示が破綻する)。
String maskApiKeyForDisplay(String key) {
  final trimmed = key.trim();
  if (trimmed.length <= 4) {
    return '•' * trimmed.length;
  }
  return '••••••••${trimmed.substring(trimmed.length - 4)}';
}

/// 設定: APIキー管理・通知設定・サブスク管理（設計書 Step2）。MVPは基本項目のみ。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final apps = ref.watch(connectedAppsProvider);
    final plan = ref.watch(userPlanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.settingsPlanLabel),
            subtitle: Text(
                plan == UserPlan.pro ? l10n.settingsPlanPro : l10n.settingsPlanFree),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.settingsAppsManagementLabel),
            subtitle: Text(l10n.settingsAppsCount(apps.length)),
          ),
          for (final app in apps) _AppSettingsTile(app: app),
          const Divider(),
          ListTile(
            title: Text(l10n.settingsNotificationLabel),
            subtitle: Text(l10n.settingsNotificationSubtitle),
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
  late final Future<String?> _apiKeyFuture;

  @override
  void initState() {
    super.initState();
    // initState時点で1回だけ取得する(buildのたびにSecure Storageへ再アクセス
    // しないようFutureをキャッシュする)。削除操作自体は別途_remove()で行う。
    _apiKeyFuture =
        ref.read(secureStorageServiceProvider).readApiKey(widget.app.id);
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _removing = true);
    try {
      await ref.read(connectedAppsProvider.notifier).removeApp(widget.app.id);
      // 成功時は state からアプリが消えるため、この Widget 自体が破棄される
      // （setState は不要、かつ破棄後のsetStateはエラーになるため呼ばない）。
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsRemoveFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      dense: true,
      title: Text(widget.app.displayName),
      subtitle: FutureBuilder<String?>(
        future: _apiKeyFuture,
        builder: (context, snapshot) {
          final key = snapshot.data;
          if (key == null || key.isEmpty) {
            return const SizedBox.shrink();
          }
          return Text(l10n.settingsApiKeyMasked(maskApiKeyForDisplay(key)));
        },
      ),
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
