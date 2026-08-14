import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_store_connect_service.dart';
import '../services/checklist_service.dart';
import '../services/local_store_service.dart';
import '../services/play_console_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/review_status_service.dart';
import '../services/secure_storage_service.dart';
import '../models/platform_type.dart';

final secureStorageServiceProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());

final localStoreServiceProvider =
    Provider<LocalStoreService>((ref) => const LocalStoreService());

final appStoreConnectServiceProvider =
    Provider<AppStoreConnectService>((ref) => AppStoreConnectService());

final playConsoleServiceProvider =
    Provider<PlayConsoleService>((ref) => PlayConsoleService());

final checklistServiceProvider =
    Provider<ChecklistService>((ref) => const ChecklistService());

final revenueCatServiceProvider =
    Provider<RevenueCatService>((ref) => const RevenueCatService());

/// プラットフォームに応じて審査状態Serviceを切り替える（設計書 Step1）。
final reviewStatusServiceProvider =
    Provider.family<ReviewStatusService, PlatformType>((ref, platform) {
  return platform == PlatformType.ios
      ? ref.watch(appStoreConnectServiceProvider)
      : ref.watch(playConsoleServiceProvider);
});
