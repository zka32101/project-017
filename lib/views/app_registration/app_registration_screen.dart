import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/discoverable_app.dart';
import '../../models/platform_type.dart';
import '../../services/service_result.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/service_providers.dart';

/// アプリ登録: プラットフォームによって「まとめて取得」の実現方式が異なる。
///
/// - iOS: App Store Connect APIに GET /v1/apps という本物の一覧取得
///   エンドポイントが存在するため、Issuer ID・Key ID・秘密鍵(.p8)を入力
///   するだけでアカウント配下の全アプリを実際に取得できる。
/// - Android: Google Play Developer API(androidpublisher)には同等の
///   エンドポイントが存在しない(既知のpackageNameに対する操作しかできない、
///   実際にDiscovery Documentで確認済み)。そのため自動検出はできず、
///   サービスアカウントJSONキーに加えて、登録したいパッケージ名を
///   ユーザー自身に入力してもらう必要がある。
class AppRegistrationScreen extends ConsumerStatefulWidget {
  const AppRegistrationScreen({super.key});

  @override
  ConsumerState<AppRegistrationScreen> createState() =>
      _AppRegistrationScreenState();
}

class _AppRegistrationScreenState
    extends ConsumerState<AppRegistrationScreen> {
  PlatformType _platform = PlatformType.ios;
  final _apiKeyController = TextEditingController(); // Android: サービスアカウントJSON
  final _issuerIdController = TextEditingController(); // iOS
  final _keyIdController = TextEditingController(); // iOS
  final _privateKeyController = TextEditingController(); // iOS
  final _packageNamesController = TextEditingController(); // Android
  bool _submitting = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _issuerIdController.dispose();
    _keyIdController.dispose();
    _privateKeyController.dispose();
    _packageNamesController.dispose();
    super.dispose();
  }

  List<String> get _packageNames => _packageNamesController.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final isIos = _platform == PlatformType.ios;

    // 入力チェック: プラットフォームごとに必要な項目が異なる。
    if (isIos) {
      if (_issuerIdController.text.trim().isEmpty ||
          _keyIdController.text.trim().isEmpty ||
          _privateKeyController.text.trim().isEmpty) {
        _showSnack(l10n.appRegistrationCredentialRequired);
        return;
      }
    } else {
      if (_apiKeyController.text.trim().isEmpty) {
        _showSnack(l10n.appRegistrationApiKeyRequired);
        return;
      }
      if (_packageNames.isEmpty) {
        _showSnack(l10n.appRegistrationPackageNamesRequired);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final service = ref.read(reviewStatusServiceProvider(_platform));
      // iOS: Issuer ID / Key ID / 秘密鍵をJSON化して単一の認証情報文字列にする
      // (SecureStorageへの保存単位・discoverApps()のシグネチャを両プラットフォーム
      // で共通化するため)。Android: 既存どおりサービスアカウントJSONそのもの。
      final apiKeyPayload = isIos
          ? jsonEncode({
              'issuerId': _issuerIdController.text.trim(),
              'keyId': _keyIdController.text.trim(),
              'privateKey': _privateKeyController.text.trim(),
            })
          : _apiKeyController.text.trim();

      final result = await service.discoverApps(
        apiKeyPayload,
        knownPackageNames: isIos ? const [] : _packageNames,
      );
      final discovered = switch (result) {
        ServiceSuccess<List<DiscoverableApp>>(:final data) => data,
        ServiceFailure<List<DiscoverableApp>> failure =>
          throw ServiceFailureException(failure),
      };

      if (discovered.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _showSnack(l10n.appRegistrationNoAppsFound);
        return;
      }

      await ref.read(connectedAppsProvider.notifier).registerAppsBulk(
            userId: 'local_user',
            platform: _platform,
            apiKey: apiKeyPayload,
            discovered: discovered,
          );
      if (!mounted) return;
      context.go('/initial-scan');
    } catch (e) {
      // APIキーの保存（Secure Storage）失敗やアプリ一覧取得の失敗などで登録処理が
      // 例外を投げても、ボタンがローディング状態のまま固まったり画面が無反応に
      // なったりしないようにする。
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(l10n.appRegistrationFailed('$e'));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIos = _platform == PlatformType.ios;
    final steps = isIos
        ? [
            l10n.appRegistrationIosStep1,
            l10n.appRegistrationIosStep2,
            l10n.appRegistrationIosStep3,
            l10n.appRegistrationIosStep4,
          ]
        : [
            l10n.appRegistrationAndroidStep1,
            l10n.appRegistrationAndroidStep2,
            l10n.appRegistrationAndroidStep3,
            l10n.appRegistrationAndroidStep4,
          ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appRegistrationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIos
                    ? l10n.appRegistrationBulkFetchDescriptionIos
                    : l10n.appRegistrationBulkFetchDescriptionAndroid,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SegmentedButton<PlatformType>(
                segments: const [
                  ButtonSegment(value: PlatformType.ios, label: Text('iOS')),
                  ButtonSegment(
                      value: PlatformType.android, label: Text('Android')),
                ],
                selected: {_platform},
                onSelectionChanged: (s) => setState(() => _platform = s.first),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.appRegistrationApiKeyStepsTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      for (var i = 0; i < steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: AppTheme.surfaceVariant,
                                child: Text('${i + 1}',
                                    style: const TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(steps[i])),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isIos) ...[
                TextField(
                  controller: _issuerIdController,
                  decoration:
                      InputDecoration(labelText: l10n.appRegistrationIssuerIdLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyIdController,
                  decoration:
                      InputDecoration(labelText: l10n.appRegistrationKeyIdLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _privateKeyController,
                  // PEM形式の秘密鍵は複数行になるため obscureText は使えない
                  // (Flutterの制約: obscureText は maxLines=1 の時のみ有効)。
                  maxLines: 6,
                  minLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.appRegistrationPrivateKeyLabel,
                    alignLabelWithHint: true,
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  maxLines: 1,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                      labelText: l10n.appRegistrationApiKeyLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _packageNamesController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.appRegistrationPackageNamesLabel,
                    hintText: l10n.appRegistrationPackageNamesHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.appRegistrationSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
