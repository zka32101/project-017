import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/gen/app_localizations.dart';
import '../models/connected_app.dart';
import '../models/review_status_type.dart';

/// SecureStorageService.writeValue/readValue経由で「通知有効/無効」設定を
/// 永続化する際の共有キー。NotificationPrePromptScreenとSettingsScreenの
/// 両方から参照する。
const notificationsEnabledStorageKey = 'notifications_enabled';

/// 通知機能（Should機能）。毎朝の状態サマリー通知(固定文言のリマインダー)と、
/// 審査状態の個別通知(状態変化時の即時通知)の2種類を担う。
///
/// 【スコープ注記】いずれも「アプリがフォアグラウンドで動いているタイミング」
/// にのみ発火する。ダッシュボードの最新状態(要注意アプリ数等)を通知本文に
/// 動的に埋め込んだり、アプリを開いていない間の状態変化を検知したりするには、
/// バックグラウンドで定期的にデータ取得する仕組み(iOS: BGTaskScheduler /
/// Android: WorkManager)が別途必要で、今回のスコープ外。そのため
/// 毎朝リマインダーは「決まった時刻に固定文言を出す」まで、個別通知は
/// 「フォアグラウンドでの実取得時に前回値と比較する」までを担う
/// (スケジューリング・許可リクエスト・個別通知自体は実際に機能する)。
/// 真のバックグラウンド動的通知は次フェーズ。
abstract class NotificationService {
  /// アプリ起動時に1回呼ぶ（main()から。Widget buildからは呼ばないこと。
  /// テストでも実行されるとプラットフォームチャネル呼び出しで落ちるため、
  /// テストでは必ずフェイクへ差し替える）。
  Future<void> initialize();

  /// OS通知許可をリクエストする。許可されればtrue。
  /// Androidは13未満では常にtrue相当(許可UIが無いため)。
  Future<bool> requestPermission();

  /// 許可ダイアログを出さずに、現在のOS通知許可状態だけを確認する。
  /// SettingsScreenのトグル表示をOS側の実際の状態と同期させるために使う
  /// (requestPermission()と違い、未許可でもダイアログは出ない)。
  Future<bool> isPermissionGranted();

  /// 毎日hour:minute(端末のローカルタイムゾーン)に固定文言のリマインダーを
  /// スケジュールする(既存のスケジュールは上書きされる)。
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0});

  /// スケジュール済みのリマインダーを取り消す。
  Future<void> cancelDailyReminder();

  /// 審査状態が変化した際に即時発火する個別通知（Should機能、大量アプリ管理の
  /// 続き）。毎朝の固定リマインダーとは別に、リジェクト/承認等の変化に
  /// すぐ気づけるようにする。タップすると該当アプリの詳細画面が開く
  /// (リジェクトの場合はリジェクト理由タブを直接開く)。
  ///
  /// 【スコープ注記】バックグラウンドでの定期取得(iOS: BGTaskScheduler /
  /// Android: WorkManager)は実装していない(クラス冒頭のコメント参照)ため、
  /// この通知は「アプリがフォアグラウンドで審査状態の実取得に成功した
  /// タイミング」でのみ発火する。呼び出し元は
  /// dashboard_providers.dartのlatestReviewStatusProvider。
  Future<void> showReviewStatusChangedNotification({
    required ConnectedApp app,
    required ReviewStatusType newStatus,
  });

  /// アプリが通知タップで起動された場合(端末再起動後や完全終了状態からの
  /// タップ)、その通知のpayloadを返す。通常起動時や、通知タップ以外での
  /// 起動ではnull。main()からrunApp()前に一度だけ呼び、ディープリンク
  /// 先へ遷移させるために使う。
  Future<String?> getLaunchPayload();
}

class LocalNotificationService implements NotificationService {
  /// onNotificationTap: 通知タップ時に呼ばれるコールバック。引数は
  /// showReviewStatusChangedNotification()が設定したpayload(ルートパス)。
  /// main()で作成したGoRouterのpush/goを渡す想定(main.dart参照)。
  /// initialize()を呼んだインスタンスでのみ意味を持つ(このコールバックは
  /// プラットフォームチャネル側に登録される)。
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.onNotificationTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String payload)? onNotificationTap;

  static const _dailyReminderNotificationId = 1001;
  static const _channelId = 'ririkan_daily_summary';

  // 個別の状態変化通知のID帯。1つのアプリにつき1通知IDを割り当てて
  // 上書き通知(同じアプリで連続して状態が変わった場合、前の通知を消して
  // 最新の1通だけ残す)にする。日次リマインダー(1001)と衝突しないよう
  // 十分に大きいオフセットを取る。
  static const _statusChangeChannelId = 'ririkan_status_change';

  bool _timeZoneInitialized = false;

  @override
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS側の許可リクエストは(プレプロンプト画面から)明示的なタイミングで
    // 行いたいため、初期化時には要求しない(requestPermission()で別途行う)。
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
    await _ensureTimeZoneInitialized();
  }

  Future<void> _ensureTimeZoneInitialized() async {
    if (_timeZoneInitialized) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 端末のタイムゾーン取得に失敗した場合はUTC基準のままにする
      // (通知時刻がずれるだけで、機能自体は壊れない)。
    }
    _timeZoneInitialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted =
          await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    await _ensureTimeZoneInitialized();
    final l10n = _resolveLocalizations();
    await _plugin.zonedSchedule(
      _dailyReminderNotificationId,
      l10n.appTitle,
      l10n.notificationDailyReminderBody,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.notificationDailyChannelName,
          channelDescription: l10n.notificationDailyChannelDescription,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // exactAllowWhileIdleはAndroid 12+でSCHEDULE_EXACT_ALARM権限が別途必要になる。
      // 「毎朝だいたいこの時刻」で十分な用途のため、権限不要なinexactを使う。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      // タップした際に個別通知(showReviewStatusChangedNotification)と同様に
      // ディープリンクさせる(ダッシュボードを開く)。以前はpayload未設定で
      // タップしても何も起きなかった(通知タップ→遷移の導線が個別通知だけに
      // 結線されていた不整合を修正)。
      payload: '/dashboard',
    );
  }

  @override
  Future<void> cancelDailyReminder() =>
      _plugin.cancel(_dailyReminderNotificationId);

  @override
  Future<void> showReviewStatusChangedNotification({
    required ConnectedApp app,
    required ReviewStatusType newStatus,
  }) async {
    final l10n = _resolveLocalizations();
    final tabQuery = newStatus == ReviewStatusType.rejected ? '?tab=3' : '';
    await _plugin.show(
      _statusChangeNotificationId(app.id),
      l10n.appTitle,
      l10n.notificationStatusChangedBody(
        app.displayName,
        newStatus.label(l10n),
      ),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _statusChangeChannelId,
          l10n.notificationStatusChangeChannelName,
          channelDescription: l10n.notificationStatusChangeChannelDescription,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '/app-detail/${app.id}$tabQuery',
    );
  }

  @override
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  /// モデル層(ReviewStatusType.label)・通知文言はBuildContextの外
  /// (main()や本Service)から呼ばれるため、端末のロケールから直接
  /// AppLocalizationsを解決する。MaterialAppの標準ロケール解決と同様、
  /// 言語コードが一致するsupportedLocaleが無ければ先頭(en)にフォールバック。
  AppLocalizations _resolveLocalizations() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final matched = AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == deviceLocale.languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    return lookupAppLocalizations(matched);
  }

  /// アプリごとに1つの通知IDを割り当て、同じアプリで連続して状態が
  /// 変わっても通知が積み上がらないようにする(常に最新の1通に上書き)。
  /// 日次リマインダー(1001)と衝突しないよう十分大きいオフセットを足す。
  int _statusChangeNotificationId(String appId) =>
      1000000 + (appId.hashCode & 0x7fffffff) % 1000000;

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
