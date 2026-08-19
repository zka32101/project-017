import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// 「広告を消す」購入フロー（RevenueCatのクライアントSDK、purchases_flutter経由）。
///
/// 注意: これはREST APIベースの分析用連携(RevenueCatOAuthService/
/// RevenueCatApiClient、売上・DL数タブで使用)とは完全に別物。あちらはOAuth
/// 2.0のアクセストークンで「自分のアプリの売上データを読む」用途、こちらは
/// RevenueCatの**公開SDKキー**でエンドユーザーの実際の購入処理(App内課金)を
/// 行う用途で、認証方式もキーの種類も異なる。
abstract class PurchaseService {
  /// main()で1回だけ呼ぶ（Widget buildからは呼ばない）。
  Future<void> initialize();

  /// 「広告を消す」エンタイトルメントが有効かどうか。
  /// 未初期化・ネットワークエラー等で確認できない場合はnullを返す
  /// (falseとは区別する。呼び出し側はnullの場合、既存のローカルキャッシュを
  /// 信用不能な情報で上書きしないこと。詳細はRevenueCatPurchaseServiceの
  /// ドキュメントコメント参照)。
  Future<bool?> isAdsRemoved();

  /// 「広告を消す」購入対象のPackage(月額プラン)を取得する。
  /// Offering/Packageが未設定、現在のOfferingに月額パッケージが無い、
  /// または未初期化(SDKキー未設定)ならnull。
  /// UI側(PaywallScreen)は「{価格} / 月」と表示するため、月額以外の
  /// パッケージ(年額・週額等)へフォールバックしてはならない(実際の課金
  /// 周期と表示が食い違う、誤解を招く価格表示になる)。
  Future<Package?> getRemoveAdsPackage();

  /// 購入を実行する。成功時true、ユーザーによるキャンセル時false、
  /// それ以外のエラーは例外として投げる。
  Future<bool> purchaseRemoveAds(Package package);

  /// 別端末での購入を復元する（iOSのApp Storeレビューガイドライン上、
  /// 復元手段の提供が必須）。
  Future<bool> restorePurchases();
}

class RevenueCatPurchaseService implements PurchaseService {
  RevenueCatPurchaseService();

  /// 「広告を消す」エンタイトルメントのID。RevenueCatダッシュボード側の
  /// Entitlement識別子と一致させること。
  static const _removeAdsEntitlementId = 'remove_ads';

  /// 【要設定】RevenueCatダッシュボードの Project Settings > API Keys から
  /// 取得した公開SDKキー(Public SDK Key、`appl_...`/`goog_...`)に置き換える
  /// こと。分析用連携で使うOAuthのclient_id/client_secretとは別物。
  /// プレースホルダのままの場合はinitialize()が実際の設定をスキップし、
  /// 常に「広告あり・購入不可」状態のまま安全に動作する(クラッシュしない)。
  static const _iosApiKey = 'REPLACE_WITH_REVENUECAT_IOS_PUBLIC_SDK_KEY';
  static const _androidApiKey = 'REPLACE_WITH_REVENUECAT_ANDROID_PUBLIC_SDK_KEY';

  // Purchases自体が静的メソッドのみで構成されるSDKであるため、設定済みかどうかも
  // インスタンスではなくstaticで保持する。main()でinitialize()したインスタンスと、
  // RiverpodのpurchaseServiceProvider経由で後から作られる別インスタンスとで
  // 状態が食い違わないようにするため。
  static bool _configured = false;

  static bool _isPlaceholder(String key) => key.startsWith('REPLACE_WITH_');

  @override
  Future<void> initialize() async {
    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    if (_isPlaceholder(apiKey)) {
      _configured = false;
      return;
    }
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
  }

  @override
  Future<bool?> isAdsRemoved() async {
    // 未設定(プレースホルダキーのまま)では確認自体ができないためnull。
    // falseを返すと「確認した結果、未購入」と区別が付かず、呼び出し側
    // (appBootstrapProvider)がこれを根拠にローカルの購入済みキャッシュを
    // 誤って上書きしてしまう(実際に購入済みのユーザーが一時的な通信エラー
    // 等でfalse判定されると、広告が復活してしまう不具合につながる)。
    if (!_configured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_removeAdsEntitlementId);
    } catch (_) {
      // ネットワークエラー等で確認できなかった場合もnull(「未購入と確定」
      // ではなく「わからない」)。理由は上記コメントと同じ。
      return null;
    }
  }

  @override
  Future<Package?> getRemoveAdsPackage() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      // 月額以外へフォールバックしない(インターフェースのドキュメント参照)。
      return offerings.current?.monthly;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> purchaseRemoveAds(Package package) async {
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_removeAdsEntitlementId);
    } catch (_) {
      return false;
    }
  }
}
