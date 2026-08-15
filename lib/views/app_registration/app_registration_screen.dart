import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/platform_type.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';

/// アプリ登録: APIキー発行手順ガイド付き（設計書 Step2 唯一の重い手動作業）。
/// 進捗バー「あと1ステップ（APIキー貼り付け）で自動監視が始まります」を表示し、
/// 「ここから先は何もしなくていい」という体験の切り替わりを可視化する（致命的リスク①対策）。
class AppRegistrationScreen extends ConsumerStatefulWidget {
  const AppRegistrationScreen({super.key});

  @override
  ConsumerState<AppRegistrationScreen> createState() =>
      _AppRegistrationScreenState();
}

class _AppRegistrationScreenState
    extends ConsumerState<AppRegistrationScreen> {
  PlatformType _platform = PlatformType.ios;
  final _bundleIdController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _bundleIdController.dispose();
    _displayNameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  double get _progress {
    var steps = 0.0;
    if (_bundleIdController.text.trim().isNotEmpty) steps += 1;
    if (_displayNameController.text.trim().isNotEmpty) steps += 1;
    if (_apiKeyController.text.trim().isNotEmpty) steps += 1;
    return steps / 3;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_bundleIdController.text.trim().isEmpty ||
        _displayNameController.text.trim().isEmpty ||
        _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.appRegistrationFillAllFields)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(connectedAppsProvider.notifier).registerApp(
            userId: 'local_user',
            platform: _platform,
            bundleIdOrPackageName: _bundleIdController.text.trim(),
            displayName: _displayNameController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          );
      if (!mounted) return;
      context.go('/initial-scan');
    } catch (e) {
      // APIキーの保存（Secure Storage）失敗などで登録処理が例外を投げても、
      // ボタンがローディング状態のまま固まったり画面が無反応になったりしないようにする。
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
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppTheme.surfaceVariant,
                color: AppTheme.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                _progress >= 1
                    ? l10n.appRegistrationProgressAlmostDone
                    : l10n.appRegistrationProgressStart,
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
                controller: _displayNameController,
                onChanged: (_) => setState(() {}),
                decoration:
                    InputDecoration(labelText: l10n.appRegistrationDisplayNameLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bundleIdController,
                onChanged: (_) => setState(() {}),
                // Bundle ID/Package Nameは英数字・ドットのみ。日本語IMEでのローマ字変換を防ぐため
                // 英数字専用キーボードを強制する（visiblePasswordは記号入力もしやすく実務上定番）。
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: _platform == PlatformType.ios
                      ? l10n.appRegistrationBundleIdLabel
                      : l10n.appRegistrationPackageNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                onChanged: (_) => setState(() {}),
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
