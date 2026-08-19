import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/services/purchase_service.dart';

void main() {
  // RevenueCat公開SDKキーは現状プレースホルダ値のままのため、initialize()は
  // Purchases.configure()を呼ばず未設定のまま終わる(実プラットフォーム
  // チャネルに一切触れないため、この範囲はflutter test環境でも安全に検証できる)。
  // 実際の鍵が設定された場合の挙動(Purchases.*呼び出し)はSDK側の責務であり、
  // ここではテストしない。
  group('RevenueCatPurchaseService（プレースホルダキーのまま）', () {
    test('initialize()は例外を投げず、未設定状態のままになる', () async {
      final service = RevenueCatPurchaseService();
      await expectLater(service.initialize(), completes);
    });

    test('未設定のままisAdsRemoved()はnull(確認不能)を返す(プラットフォームチャネル未使用)',
        () async {
      // falseではなくnullを返すのが重要: 呼び出し側(appBootstrapProvider)が
      // これを「確認した結果、未購入」と誤解してローカルの購入済みキャッシュを
      // 上書きしないようにするため(詳細はPurchaseService.isAdsRemoved()の
      // ドキュメントコメント参照)。
      final service = RevenueCatPurchaseService();
      await service.initialize();
      expect(await service.isAdsRemoved(), isNull);
    });

    test('未設定のままgetRemoveAdsPackage()はnullを返す(プラットフォームチャネル未使用)',
        () async {
      final service = RevenueCatPurchaseService();
      await service.initialize();
      expect(await service.getRemoveAdsPackage(), isNull);
    });

    test('未設定のままrestorePurchases()はfalseを返す(プラットフォームチャネル未使用)',
        () async {
      final service = RevenueCatPurchaseService();
      await service.initialize();
      expect(await service.restorePurchases(), isFalse);
    });
  });
}
