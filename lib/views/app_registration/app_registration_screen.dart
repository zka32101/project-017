import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (_bundleIdController.text.trim().isEmpty ||
        _displayNameController.text.trim().isEmpty ||
        _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての項目を入力してください')),
      );
      return;
    }
    setState(() => _submitting = true);
    await ref.read(connectedAppsProvider.notifier).registerApp(
          userId: 'local_user',
          platform: _platform,
          bundleIdOrPackageName: _bundleIdController.text.trim(),
          displayName: _displayNameController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
        );
    if (!mounted) return;
    context.go('/initial-scan');
  }

  @override
  Widget build(BuildContext context) {
    final steps = _platform == PlatformType.ios
        ? const [
            'App Store Connect にログイン',
            'ユーザーとアクセス → 統合 → キーを生成',
            '「App Manager」以上の最小権限スコープで発行',
            '発行された Issuer ID / Key ID / .p8 の内容をコピー',
          ]
        : const [
            'Google Play Console にログイン',
            'API アクセス → サービスアカウントを作成',
            '最小権限ロール（表示専用など）で発行',
            'サービスアカウントJSONキーの内容をコピー',
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('アプリ登録')),
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
                    ? 'あと1ステップで自動監視が始まります'
                    : 'ここだけ頑張れば、あとは全部自動です',
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
                      const Text('APIキー発行手順（ユーザー作業）',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: 'アプリの表示名'),
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
                      ? 'Bundle ID'
                      : 'Package Name',
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
                decoration: const InputDecoration(
                  labelText: 'APIキー（端末内にのみ暗号化保存されます）',
                ),
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
                    : const Text('登録して初回スキャンを開始'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
