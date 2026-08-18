import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ad_service.dart';
import '../services/app_store_connect_service.dart';
import '../services/checklist_service.dart';
import '../services/local_store_service.dart';
import '../services/notification_service.dart';
import '../services/play_console_service.dart';
import '../services/purchase_service.dart';
import '../services/revenue_cat_oauth_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/review_status_service.dart';
import '../services/secure_storage_service.dart';
import '../views/widgets/ad_banner_widget.dart';
import '../models/platform_type.dart';

final secureStorageServiceProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());

final localStoreServiceProvider =
    Provider<LocalStoreService>((ref) => const LocalStoreService());

final appStoreConnectServiceProvider = Provider<AppStoreConnectService>(
  (ref) => AppStoreConnectService(
    secureStorageService: ref.watch(secureStorageServiceProvider),
  ),
);

final playConsoleServiceProvider = Provider<PlayConsoleService>(
  (ref) => PlayConsoleService(
    secureStorageService: ref.watch(secureStorageServiceProvider),
  ),
);

final checklistServiceProvider =
    Provider<ChecklistService>((ref) => const ChecklistService());

/// main()でinitialize()を呼ぶ想定の実体。テストでは必ずFakeNotificationServiceへ
/// overrideWithValueすること(実プラグインはプラットフォームチャネル呼び出しが
/// 発生しflutter test環境では動作しない)。
final notificationServiceProvider =
    Provider<NotificationService>((ref) => LocalNotificationService());

final revenueCatOAuthServiceProvider = Provider<RevenueCatOAuthService>(
  (ref) => RevenueCatOAuthService(
    secureStorageService: ref.watch(secureStorageServiceProvider),
  ),
);

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService(
    oauthService: ref.watch(revenueCatOAuthServiceProvider),
  ),
);

/// バナー広告表示(MobileAds.instance.initialize()はmain()で1回だけ呼ぶ)。
final adServiceProvider = Provider<AdService>((ref) => const AdService());

/// バナー広告Widgetの差し込み口。実Widgetはプラットフォームチャネルへ触れる
/// ため、テストでは必ずダミーのWidgetBuilderへoverrideWithValueすること。
final adBannerWidgetBuilderProvider = Provider<WidgetBuilder>(
  (ref) => (context) => const AdBannerWidget(),
);

/// 「広告を消す」購入（RevenueCatのクライアントSDK、purchases_flutter経由）。
/// 分析用のrevenueCatServiceProvider/revenueCatOAuthServiceProviderとは別物。
final purchaseServiceProvider =
    Provider<PurchaseService>((ref) => RevenueCatPurchaseService());

/// プラットフォームに応じて審査状態Serviceを切り替える（設計書 Step1）。
final reviewStatusServiceProvider =
    Provider.family<ReviewStatusService, PlatformType>((ref, platform) {
  return platform == PlatformType.ios
      ? ref.watch(appStoreConnectServiceProvider)
      : ref.watch(playConsoleServiceProvider);
});
