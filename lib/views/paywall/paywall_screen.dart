import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/user_plan.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/connected_apps_notifier.dart';
import '../../viewmodels/service_providers.dart';

/// ペイウォール: 「広告を消す」購入（マネタイズ: 無料ユーザーには広告表示、
/// 月$1の購入で広告非表示）。ダッシュボードの「広告を消す」ボタンから遷移する。
/// PurchaseService(RevenueCatのpurchases_flutter)経由で実際の課金処理を行う。
/// 【要設定】RevenueCatの公開SDKキーが未設定(プレースホルダのまま)の場合、
/// getRemoveAdsPackage()がnullを返し、この画面は「現在ご利用いただけません」
/// 表示のまま購入できない(クラッシュはしない)。
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Package? _package;
  bool _loadingPackage = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPackage();
  }

  Future<void> _loadPackage() async {
    final package = await ref.read(purchaseServiceProvider).getRemoveAdsPackage();
    if (!mounted) return;
    setState(() {
      _package = package;
      _loadingPackage = false;
    });
  }

  Future<void> _purchase() async {
    final package = _package;
    if (package == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final success =
          await ref.read(purchaseServiceProvider).purchaseRemoveAds(package);
      if (success) {
        await ref.read(connectedAppsProvider.notifier).setPlan(UserPlan.pro);
        if (mounted) context.pop();
        return;
      }
      // successがfalseの場合はユーザーによるキャンセルのため、何も表示せず
      // この画面に留まる(RevenueCatPurchaseService.purchaseRemoveAdsの契約)。
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paywallUnavailable)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final restored = await ref.read(purchaseServiceProvider).restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    if (restored) {
      await ref.read(connectedAppsProvider.notifier).setPlan(UserPlan.pro);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final package = _package;
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
              if (_loadingPackage)
                const CircularProgressIndicator()
              else if (package == null)
                Text(
                  l10n.paywallUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger),
                )
              else ...[
                ElevatedButton(
                  onPressed: _busy ? null : _purchase,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.paywallPriceLabel(package.storeProduct.priceString)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l10n.paywallRestore,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
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
