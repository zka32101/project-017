import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/crash_summary.dart';
import 'google_service_account_oauth.dart';

/// Play Developer Reporting APIへの認証・通信失敗を表す例外。
/// メッセージは開発者向けの詳細情報であり、UI側は
/// ServiceFailureReason.crashSummaries を経由してローカライズ済み
/// メッセージへ変換するため、そのまま画面表示はしない。
class PlayDeveloperReportingAuthException implements Exception {
  final String message;
  const PlayDeveloperReportingAuthException(this.message);

  @override
  String toString() => 'PlayDeveloperReportingAuthException($message)';
}

/// Google Play Developer Reporting API (playdeveloperreporting) 実接続クライアント。
///
/// androidpublisher(Google Play Developer API)とは別のAPI・別のホスト
/// (playdeveloperreporting.googleapis.com)・別のOAuthスコープ
/// (https://www.googleapis.com/auth/playdeveloperreporting) を使う。
/// そのためサービスアカウントJSONは同じものを使い回せるが、Play Console側で
/// このアプリに対する「アプリ情報の表示（読み取り専用）」権限が別途
/// 付与されている必要がある(androidpublisherの権限とは独立)。
///
/// クラッシュ率は vitals.crashrate.query
/// (POST /v1beta1/apps/{packageName}/crashRateMetricSet:query) を呼び、
/// 日次(DAILY)集計の crashRate(クラッシュを経験したユーザーの割合)と
/// distinctUsers(正規化に使われた対象ユーザー数)を取得する。
///
/// 注意: このAPIには「クラッシュ発生回数」そのものを表すメトリクスは無い
/// (crashRateはユーザー単位の割合のみ)。CrashSummary.crashCount には
/// distinctUsers × crashRate から算出した「クラッシュを経験したユーザー数の
/// 概算値」を入れており、実際のクラッシュイベント発生回数ではない近似値である
/// ことに注意(詳細なクラッシュ回数が必要な場合は vitals.errors.counts を
/// 別途使う必要があるが、今回のスコープ外)。
class PlayDeveloperReportingApiClient {
  PlayDeveloperReportingApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _apiBaseUrl =
      'https://playdeveloperreporting.googleapis.com/v1beta1';
  static const _scope =
      'https://www.googleapis.com/auth/playdeveloperreporting';

  /// 直近[days]日分の日次クラッシュ率を取得する。
  /// DAILY集計はタイムゾーンがAmerica/Los_Angeles固定(API仕様)。
  Future<List<CrashSummary>> fetchCrashSummaries({
    required String serviceAccountJson,
    required String packageName,
    required String connectedAppId,
    int days = 7,
  }) async {
    final accessToken = await _fetchAccessToken(serviceAccountJson);

    final now = DateTime.now();
    final end = _DateOnly(now.year, now.month, now.day);
    final start = end.subtractDays(days);

    final uri = Uri.parse(
      '$_apiBaseUrl/apps/$packageName/crashRateMetricSet:query',
    );
    final requestBody = jsonEncode({
      'timelineSpec': {
        'aggregationPeriod': 'DAILY',
        'startTime': start.toRequestJson(),
        'endTime': end.toRequestJson(),
      },
      'metrics': ['crashRate', 'distinctUsers'],
    });

    final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw PlayDeveloperReportingAuthException(
        'Play Developer Reporting APIへの接続に失敗しました: $e',
      );
    }

    if (response.statusCode != 200) {
      throw PlayDeveloperReportingAuthException(
        'クラッシュ率の取得に失敗しました(HTTP ${response.statusCode})。'
        'サービスアカウントに「アプリ情報の表示」権限が付与されているか確認してください。',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['rows'] as List<dynamic>?) ?? const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => _rowToCrashSummary(row, connectedAppId))
        .whereType<CrashSummary>()
        .toList();
  }

  CrashSummary? _rowToCrashSummary(
    Map<String, dynamic> row,
    String connectedAppId,
  ) {
    final startTime = row['startTime'] as Map<String, dynamic>?;
    if (startTime == null) return null;
    final year = startTime['year'] as int?;
    final month = startTime['month'] as int?;
    final day = startTime['day'] as int?;
    if (year == null || month == null || day == null) return null;

    final metrics = (row['metrics'] as List<dynamic>?) ?? const [];
    double? crashRate;
    double? distinctUsers;
    for (final m in metrics.whereType<Map<String, dynamic>>()) {
      final name = m['metric'] as String?;
      final decimalValue = m['decimalValue'] as Map<String, dynamic>?;
      final value = double.tryParse((decimalValue?['value'] as String?) ?? '');
      if (name == 'crashRate') crashRate = value;
      if (name == 'distinctUsers') distinctUsers = value;
    }
    if (crashRate == null) return null;

    // distinctUsersはこのAPIの仕様上10/100/1,000/1,000,000単位に丸められた
    // 概算値であり、crashCountもそれに応じた概算値になる(コードコメント参照)。
    final affectedUsers = distinctUsers == null
        ? 0
        : (distinctUsers * crashRate / 100).round();

    return CrashSummary(
      id: '${connectedAppId}_crash_${year}_${month}_$day',
      connectedAppId: connectedAppId,
      date: DateTime(year, month, day),
      crashFreeRate: (100 - crashRate).clamp(0, 100),
      crashCount: math.max(0, affectedUsers),
    );
  }

  // JWT組み立て〜oauth2/tokenへのPOSTはAndroidPublisherApiClientと完全に
  // 共通の手順のため、google_service_account_oauth.dartへ切り出してある
  // (詳細な手順のコメントはそちらを参照)。
  Future<String> _fetchAccessToken(String serviceAccountJson) =>
      fetchGoogleServiceAccountAccessToken(
        serviceAccountJson: serviceAccountJson,
        scope: _scope,
        httpClient: _httpClient,
        exceptionBuilder: (message) =>
            PlayDeveloperReportingAuthException(message),
      );
}

/// 時刻を持たない日付だけの値。Play Developer Reporting APIのDAILY集計は
/// GoogleTypeDateTimeの year/month/day のみを使い、hours/minutes/seconds/nanos
/// は未設定でなければならない(API仕様)ため、専用の軽量な型で表現する。
class _DateOnly {
  const _DateOnly(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  _DateOnly subtractDays(int days) {
    final d = DateTime(year, month, day).subtract(Duration(days: days));
    return _DateOnly(d.year, d.month, d.day);
  }

  Map<String, dynamic> toRequestJson() => {
        'year': year,
        'month': month,
        'day': day,
      };
}
