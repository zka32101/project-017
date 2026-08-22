import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/connected_app.dart';
import '../../models/user_plan.dart';
import '../../services/notification_service.dart';
import '../../services/revenue_cat_oauth_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/export_provider.dart';
import '../../viewmodels/service_providers.dart';

/// 登録アプリ一覧（表示名・プラットフォーム・バンドルID/パッケージ名・タグ）を
/// CSVで書き出し、共有シートを開く（大量アプリ管理: 台帳としてのエクスポート）。
/// generate()/generateAll()による審査履歴等のエクスポートとは別物のため、
/// ExportScreenではなくこの設定画面から直接呼び出す軽量な導線にしている。
Future<void> _exportAppRoster(
  BuildContext context,
  WidgetRef ref,
  List<ConnectedApp> apps,
) async {
  final l10n = AppLocalizations.of(context);
  final path = await ref.read(exportServiceProvider).exportAppRoster(apps);
  if (!context.mounted) return;
  if (path == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsExportRosterFailed)));
    return;
  }
  await Share.shareXFiles([XFile(path)]);
}

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
              plan == UserPlan.pro
                  ? l10n.settingsPlanPro
                  : l10n.settingsPlanFree,
            ),
            trailing: plan == UserPlan.free
                ? TextButton(
                    onPressed: () => context.push('/paywall'),
                    child: Text(l10n.dashboardRemoveAds),
                  )
                : null,
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.settingsAppsManagementLabel),
            subtitle: Text(l10n.settingsAppsCount(apps.length)),
            trailing: apps.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.ios_share_outlined),
                    tooltip: l10n.settingsExportRosterTooltip,
                    onPressed: () => _exportAppRoster(context, ref, apps),
                  ),
          ),
          for (final app in apps) _AppSettingsTile(app: app),
          const Divider(),
          const _RevenueCatConnectionTile(),
          const Divider(),
          const _NotificationToggleTile(),
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
  bool _rotating = false;
  // late final ではなくlateにしているのは、APIキー再登録(_rotateApiKey)成功時に
  // マスク表示を最新化するため差し替える必要があるため。
  late Future<String?> _apiKeyFuture;

  @override
  void initState() {
    super.initState();
    _refreshApiKeyFuture();
  }

  // initState時点・再登録成功時に呼び、buildのたびにSecure Storageへ
  // 再アクセスしないようFutureをキャッシュする。
  void _refreshApiKeyFuture() {
    _apiKeyFuture = ref
        .read(secureStorageServiceProvider)
        .readApiKey(widget.app.id);
  }

  /// APIキーの再登録(ローテーション)。App Store Connect/Play Consoleの
  /// キーが失効・再発行された場合に、アプリを削除して登録し直す
  /// (チェックリスト進捗・管理メモ・タグ・並び順を失う)必要が無いようにする。
  Future<void> _rotateApiKey() async {
    final l10n = AppLocalizations.of(context);
    final newKey = await showDialog<String>(
      context: context,
      builder: (context) => _RotateApiKeyDialog(l10n: l10n),
    );
    if (newKey == null || newKey.isEmpty || !mounted) return;

    setState(() => _rotating = true);
    try {
      await ref
          .read(connectedAppsProvider.notifier)
          .updateApiKey(widget.app.id, newKey);
      if (!mounted) return;
      setState(() {
        _rotating = false;
        _refreshApiKeyFuture();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsRotateApiKeySuccess)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _rotating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsRemoveFailed('$e'))));
    }
  }

  /// 削除は元に戻せず、Secure Storageのキー・チェックリスト進捗も一緒に
  /// 消えるため、誤タップによる意図しない削除を防ぐ確認ダイアログを挟む。
  Future<void> _confirmAndRemove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsRemoveConfirmTitle),
        content: Text(
          l10n.settingsRemoveConfirmMessage(widget.app.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _remove();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsRemoveFailed('$e'))));
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
      trailing: _removing || _rotating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.key_outlined),
                  tooltip: l10n.settingsRotateApiKeyTooltip,
                  onPressed: _rotateApiKey,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.commonDelete,
                  onPressed: _confirmAndRemove,
                ),
              ],
            ),
    );
  }
}

/// APIキー再登録の入力ダイアログ。controllerの生存期間をこのWidget自身の
/// State.dispose()に委ねる(_rotateApiKey側でshowDialog()の完了直後に
/// controller.dispose()を呼ぶ実装だと、ダイアログの閉じるアニメーションが
/// 完了する前にcontrollerが破棄され"Tried to build dirty widget in the
/// wrong build scope"を引き起こすことがあったため、_BulkTagEditDialog
/// (dashboard_screen.dart)と同じ自己完結パターンに統一している)。
class _RotateApiKeyDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _RotateApiKeyDialog({required this.l10n});

  @override
  State<_RotateApiKeyDialog> createState() => _RotateApiKeyDialogState();
}

class _RotateApiKeyDialogState extends State<_RotateApiKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.settingsRotateApiKeyTitle),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: widget.l10n.appRegistrationApiKeyLabel,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.l10n.commonSave),
        ),
      ],
    );
  }
}

/// RevenueCat連携（売上・DL数の実データ化）。App Store Connect/Play Console
/// のようなアプリ単位のAPIキー入力とは異なり、OAuth 2.0接続がアプリ全体で
/// 1回だけ必要になる（RevenueCatOAuthServiceのドキュメントコメント参照）。
class _RevenueCatConnectionTile extends ConsumerStatefulWidget {
  const _RevenueCatConnectionTile();

  @override
  ConsumerState<_RevenueCatConnectionTile> createState() =>
      _RevenueCatConnectionTileState();
}

class _RevenueCatConnectionTileState
    extends ConsumerState<_RevenueCatConnectionTile> {
  bool? _connected;
  bool _busy = false;
  bool _showConnectForm = false;
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  RevenueCatOAuthService get _oauth => ref.read(revenueCatOAuthServiceProvider);

  Future<void> _refreshStatus() async {
    final connected = await _oauth.isConnected();
    if (!mounted) return;
    setState(() => _connected = connected);
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _oauth.connect(
        clientId: _clientIdController.text.trim(),
        clientSecret: _clientSecretController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showConnectForm = false;
        _connected = true;
      });
      _clientIdController.clear();
      _clientSecretController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsRevenueCatConnectFailed('$e'))),
      );
    }
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _oauth.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _connected = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsRevenueCatDisconnectFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connected = _connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.settingsRevenueCatLabel),
          subtitle: Text(
            connected == null
                ? ''
                : (connected
                      ? l10n.settingsRevenueCatConnected
                      : l10n.settingsRevenueCatNotConnected),
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (connected == true
                    ? TextButton(
                        onPressed: _disconnect,
                        child: Text(l10n.settingsRevenueCatDisconnectButton),
                      )
                    : TextButton(
                        onPressed: () => setState(
                          () => _showConnectForm = !_showConnectForm,
                        ),
                        child: Text(l10n.settingsRevenueCatConnectButton),
                      )),
        ),
        if (connected == false && _showConnectForm)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsRevenueCatConnectHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clientIdController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsRevenueCatClientIdLabel,
                  ),
                ),
                TextField(
                  controller: _clientSecretController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.settingsRevenueCatClientSecretLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _connect,
                    child: Text(l10n.settingsRevenueCatConnectSubmit),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }
}

/// 毎朝の状態サマリー通知（Should機能）のON/OFFトグル。
/// ONにする瞬間にOS通知許可をリクエストし、許可された場合のみ実際に
/// スケジュールする(拒否された場合はトグルをOFFに戻し、理由を表示する)。
class _NotificationToggleTile extends ConsumerStatefulWidget {
  const _NotificationToggleTile();

  @override
  ConsumerState<_NotificationToggleTile> createState() =>
      _NotificationToggleTileState();
}

class _NotificationToggleTileState
    extends ConsumerState<_NotificationToggleTile> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  /// 保存済みのON/OFF設定に加えて、OS側の実際の許可状態も確認する。
  /// ユーザーが端末のOS設定側で後から通知を拒否した場合、保存値だけを見ると
  /// トグルはON表示のまま何も届かなくなってしまう(実際には届かないのに
  /// 「ONになっている」と誤認させる)ため、OS側がfalseならトグル表示・
  /// 保存値の両方をOFFへ補正する。
  Future<void> _refreshState() async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final storedValue = await secureStorage.readValue(
      notificationsEnabledStorageKey,
    );
    final storedEnabled = storedValue == 'true';

    var effectiveEnabled = storedEnabled;
    if (storedEnabled) {
      final osGranted = await ref
          .read(notificationServiceProvider)
          .isPermissionGranted();
      if (!osGranted) {
        effectiveEnabled = false;
        await secureStorage.writeValue(
          key: notificationsEnabledStorageKey,
          value: 'false',
        );
      }
    }

    if (!mounted) return;
    setState(() => _enabled = effectiveEnabled);
  }

  Future<void> _onChanged(bool value) async {
    final l10n = AppLocalizations.of(context);
    final notificationService = ref.read(notificationServiceProvider);
    final secureStorage = ref.read(secureStorageServiceProvider);
    setState(() => _busy = true);

    if (value) {
      final granted = await notificationService.requestPermission();
      if (granted) {
        await notificationService.scheduleDailyReminder();
        await secureStorage.writeValue(
          key: notificationsEnabledStorageKey,
          value: 'true',
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _enabled = granted;
      });
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsNotificationPermissionDenied)),
        );
      }
    } else {
      await notificationService.cancelDailyReminder();
      await secureStorage.writeValue(
        key: notificationsEnabledStorageKey,
        value: 'false',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _enabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(l10n.settingsNotificationLabel),
      subtitle: Text(l10n.settingsNotificationSubtitle),
      value: _enabled ?? false,
      onChanged: _busy || _enabled == null ? null : _onChanged,
    );
  }
}
