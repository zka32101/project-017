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

/// アプリ登録: アプリ単位の手動登録ではなく、APIキー1つに紐づくアカウント配下の
/// アプリをまとめて取得して一括登録する（仕様変更: 1件ずつのBundle ID/表示名の
/// 手入力は不要）。APIキー発行手順ガイド付き（設計書 Step2 唯一の重い手動作業）。
class AppRegistrationScreen extends ConsumerStatefulWidget {
  const AppRegistrationScreen({super.key});

  @override
  ConsumerState<AppRegistrationScreen> createState() =>
      _AppRegistrationScreenState();
}

class _AppRegistrationScreenState
    extends ConsumerState<AppRegistrationScreen> {
  PlatformType _platform = PlatformType.ios;
  final _apiKeyController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appRegistrationApiKeyRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(reviewStatusServiceProvider(_platform));
      final result = await service.discoverApps(apiKey);
      final discovered = switch (result) {
        ServiceSuccess<List<DiscoverableApp>>(:final data) => data,
        ServiceFailure<List<DiscoverableApp>> failure =>
          throw ServiceFailureException(failure),
      };

      if (discovered.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.appRegistrationNoAppsFound)),
        );
        return;
      }

      await ref.read(connectedAppsProvider.notifier).registerAppsBulk(
            userId: 'local_user',
            platform: _platform,
            apiKey: apiKey,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appRegistrationFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = _platform == PlatformType.ios
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
                l10n.appRegistrationBulkFetchDescription,
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
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                maxLines: 1,
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                decoration:
                    InputDecoration(labelText: l10n.appRegistrationApiKeyLabel),
              ),
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
