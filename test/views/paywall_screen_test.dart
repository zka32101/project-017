import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/purchase_service.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

const _testPackage = Package(
  r'$rc_monthly',
  PackageType.monthly,
  StoreProduct(
    'remove_ads_monthly',
    '広告非表示',
    '広告を消す',
    1.0,
    r'$1.00',
    'USD',
  ),
  PresentedOfferingContext('default', null, null),
);

class _FakePurchaseService implements PurchaseService {
  _FakePurchaseService({
    this.package = _testPackage,
    this.purchaseSucceeds = true,
    this.throwOnPurchase,
  });

  final Package? package;
  final bool purchaseSucceeds;
  final Object? throwOnPurchase;
  int purchaseCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAdsRemoved() async => false;

  @override
  Future<Package?> getRemoveAdsPackage() async => package;

  @override
  Future<bool> purchaseRemoveAds(Package package) async {
    purchaseCallCount++;
    if (throwOnPurchase != null) throw throwOnPurchase!;
    return purchaseSucceeds;
  }

  @override
  Future<bool> restorePurchases() async => false;
}

void main() {
  late ProviderContainer container;
  late FakeLocalStoreService localStore;
  late _FakePurchaseService purchaseService;

  ProviderContainer buildContainer({_FakePurchaseService? service}) {
    localStore = FakeLocalStoreService();
    purchaseService = service ?? _FakePurchaseService();
    return ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(localStore),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
        purchaseServiceProvider.overrideWithValue(purchaseService),
      ],
    );
  }

  tearDown(() => container.dispose());

  testWidgets('パッケージ価格付きボタンをタップすると購入され、プランが更新・永続化される',
      (tester) async {
    container = buildContainer();
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.free);
    expect(find.textContaining(r'$1.00'), findsOneWidget);

    await tester.tap(find.textContaining(r'$1.00'));
    await tester.pumpAndSettle();

    expect(purchaseService.purchaseCallCount, 1);
    expect(container.read(userPlanProvider), UserPlan.pro);
    // paywall_screen.dart は userPlanProvider.notifier.state を直接書き換えず
    // ConnectedAppsNotifier.setPlan() 経由にすることで永続化される
    // （直接書き換えると再起動時に消える、PR #4のリグレッション防止）。
    final saved = await localStore.load();
    expect(saved?.plan, UserPlan.pro);
  });

  testWidgets('購入がキャンセルされるとプランは変わらずこの画面に留まる', (tester) async {
    container = buildContainer(
      service: _FakePurchaseService(purchaseSucceeds: false),
    );
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(r'$1.00'));
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.free);
    expect(find.textContaining(r'$1.00'), findsOneWidget);
  });

  testWidgets('パッケージが取得できない(未設定)場合は「現在ご利用いただけません」表示になる',
      (tester) async {
    container = buildContainer(service: _FakePurchaseService(package: null));
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    expect(find.text('現在ご利用いただけません。しばらくしてから再度お試しください。'),
        findsOneWidget);
  });

  testWidgets('購入処理が例外を投げるとエラーメッセージを表示し、プランは変わらない',
      (tester) async {
    container = buildContainer(
      service: _FakePurchaseService(throwOnPurchase: Exception('network error')),
    );
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(r'$1.00'));
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.free);
    expect(find.text('現在ご利用いただけません。しばらくしてから再度お試しください。'),
        findsOneWidget);
  });

  testWidgets('「あとで」を選ぶとプランを変えずに画面を閉じる', (tester) async {
    container = buildContainer();
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.free);
    expect(purchaseService.purchaseCallCount, 0);
  });
}
