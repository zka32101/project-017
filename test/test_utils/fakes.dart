// ウィジェットテスト共通のフェイク群。
// SecureStorageService(flutter_secure_storage)・LocalStoreService(path_provider)・
// WidgetSyncService(home_widget) はいずれも実機のプラットフォームチャネルに
//依存する実装のため、flutter test 環境では未モックのMethodChannel呼び出しが
// 例外になる。widget_test.dart や各viewmodelの単体テストと同じ理由で、
// ここに集約したインメモリ/no-opのフェイクをProviderScopeのoverridesとして渡す。

import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/crash_summary.dart';
import 'package:ririkan/models/discoverable_app.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/services/local_store_service.dart';
import 'package:ririkan/services/notification_service.dart';
import 'package:ririkan/services/review_status_service.dart';
import 'package:ririkan/services/secure_storage_service.dart';
import 'package:ririkan/services/service_result.dart';
import 'package:ririkan/services/widget_sync_service.dart';

class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) async {
    _memory[SecureStorageService.refKeyFor(connectedAppId)] = apiKey;
  }

  @override
  Future<String?> readApiKey(String connectedAppId) async =>
      _memory[SecureStorageService.refKeyFor(connectedAppId)];

  @override
  Future<void> deleteApiKey(String connectedAppId) async {
    _memory.remove(SecureStorageService.refKeyFor(connectedAppId));
  }

  // writeValue/readValue/deleteValue はSecureStorageService本体では
  // 実際のFlutterSecureStorage(プラットフォームチャネル)を直接叩くため、
  // apiKey系と同じインメモリMapを使って上書きしないとflutter test環境で
  // MissingPluginExceptionになる。
  @override
  Future<void> writeValue({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<String?> readValue(String key) async => _memory[key];

  @override
  Future<void> deleteValue(String key) async {
    _memory.remove(key);
  }
}

/// load()/loadChecklist()に固定の初期値を差し込める、永続化なしのフェイク。
/// デフォルト（初期値省略）ではデモアプリ自動投入の対象になる「保存データなし」状態。
class FakeLocalStoreService extends LocalStoreService {
  FakeLocalStoreService({LocalState? initial}) : _stored = initial;

  LocalState? _stored;

  @override
  Future<LocalState?> load() async => _stored;

  @override
  Future<void> save(LocalState state) async {
    _stored = state;
  }

  @override
  Future<List<SubmissionChecklistItem>?> loadChecklist(
    String connectedAppId,
  ) async =>
      null;

  @override
  Future<void> saveChecklist(
    String connectedAppId,
    List<SubmissionChecklistItem> items,
  ) async {}

  @override
  Future<void> deleteChecklist(String connectedAppId) async {}
}

class FakeWidgetSyncService extends WidgetSyncService {
  const FakeWidgetSyncService();

  @override
  Future<void> syncSummary({
    required int totalApps,
    required int attentionCount,
    required ConnectedApp? topAttentionApp,
  }) async {}
}

/// NotificationService(flutter_local_notifications)は実プラットフォーム
/// チャネルを叩くため、flutter test環境ではこのフェイクへ差し替える。
/// permissionGranted で requestPermission() の戻り値を制御できる。
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = true});

  final bool permissionGranted;
  bool initializeCalled = false;
  bool requestPermissionCalled = false;
  bool scheduleCalled = false;
  bool cancelCalled = false;
  int? scheduledHour;
  int? scheduledMinute;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalled = true;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    scheduleCalled = true;
    scheduledHour = hour;
    scheduledMinute = minute;
  }

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalled = true;
  }
}

/// AppStoreConnectService/PlayConsoleServiceは今やdiscoverApps/
/// fetchReviewStatusが実API接続になっているため、テスト用にダミーの
/// registerApp(apiKey: 'k')等で登録したアプリに対して確定的な結果を
/// 返すフェイクが必要になる箇所で使う（reviewStatusServiceProvider経由で
/// オーバーライドする）。デフォルト値は元のMockDataServiceが返していた
/// 値と同じにしてあり、既存テストのアサーションをそのまま使い回せる。
class FakeReviewStatusService implements ReviewStatusService {
  FakeReviewStatusService({
    this.snapshot,
    this.rejections = const [],
    this.buildFailures = const [],
    this.discoverableApps = const [],
    this.crashSummaries = const [],
  });

  final ReviewStatusSnapshot? snapshot;
  final List<RejectionDetail> rejections;
  final List<BuildFailureLog> buildFailures;
  final List<DiscoverableApp> discoverableApps;
  final List<CrashSummary> crashSummaries;

  @override
  Future<ServiceResult<List<ReviewStatusSnapshot>>> fetchReviewStatus(
    ConnectedApp app,
  ) async =>
      ServiceSuccess(snapshot == null ? [] : [snapshot!]);

  @override
  Future<ServiceResult<List<RejectionDetail>>> fetchRejectionDetails(
    ConnectedApp app,
  ) async =>
      ServiceSuccess(rejections);

  @override
  Future<ServiceResult<List<BuildFailureLog>>> fetchBuildFailureLogs(
    ConnectedApp app,
  ) async =>
      ServiceSuccess(buildFailures);

  @override
  Future<ServiceResult<List<DiscoverableApp>>> discoverApps(
    String apiKey, {
    List<String> knownPackageNames = const [],
  }) async =>
      ServiceSuccess(discoverableApps);

  @override
  Future<ServiceResult<List<CrashSummary>>> fetchCrashSummaries(
    ConnectedApp app,
  ) async =>
      ServiceSuccess(crashSummaries);
}
