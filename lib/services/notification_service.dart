import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// SecureStorageService.writeValue/readValue経由で「通知有効/無効」設定を
/// 永続化する際の共有キー。NotificationPrePromptScreenとSettingsScreenの
/// 両方から参照する。
const notificationsEnabledStorageKey = 'notifications_enabled';

/// 毎朝の状態サマリー通知（Should機能）。
///
/// 【スコープ注記】ダッシュボードの最新状態(要注意アプリ数等)を通知本文に
/// 動的に埋め込むには、通知が実際に発火する時刻に合わせてバックグラウンドで
/// 最新データを取得する仕組み(iOS: BGTaskScheduler / Android: WorkManager)が
/// 別途必要で、今回のスコープ外。そのため本実装は「決まった時刻に固定文言の
/// リマインダー通知を出す」までを担う(スケジューリング・許可リクエストは
/// 実際に機能する)。動的な本文生成は次フェーズ。
abstract class NotificationService {
  /// アプリ起動時に1回呼ぶ（main()から。Widget buildからは呼ばないこと。
  /// テストでも実行されるとプラットフォームチャネル呼び出しで落ちるため、
  /// テストでは必ずフェイクへ差し替える）。
  Future<void> initialize();

  /// OS通知許可をリクエストする。許可されればtrue。
  /// Androidは13未満では常にtrue相当(許可UIが無いため)。
  Future<bool> requestPermission();

  /// 毎日hour:minute(端末のローカルタイムゾーン)に固定文言のリマインダーを
  /// スケジュールする(既存のスケジュールは上書きされる)。
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0});

  /// スケジュール済みのリマインダーを取り消す。
  Future<void> cancelDailyReminder();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _dailyReminderNotificationId = 1001;
  static const _channelId = 'ririkan_daily_summary';
  static const _channelName = '毎朝の状態サマリー';
  static const _channelDescription = '登録アプリの審査状況を毎朝リマインドします';

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
    await _plugin.initialize(settings);
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
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    await _ensureTimeZoneInitialized();
    await _plugin.zonedSchedule(
      _dailyReminderNotificationId,
      'リリカン',
      '本日の審査状況をチェックしましょう',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // exactAllowWhileIdleはAndroid 12+でSCHEDULE_EXACT_ALARM権限が別途必要になる。
      // 「毎朝だいたいこの時刻」で十分な用途のため、権限不要なinexactを使う。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() =>
      _plugin.cancel(_dailyReminderNotificationId);

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
