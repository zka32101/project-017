import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/review_status_snapshot.dart';
import '../models/review_status_type.dart';
import 'google_service_account_oauth.dart';

/// Google Play Developer APIへの認証・通信失敗を表す例外。
/// メッセージは開発者向けの詳細情報であり、UI側は
/// ServiceFailureReason.reviewStatus を経由してローカライズ済み
/// メッセージへ変換するため、そのまま画面表示はしない。
class AndroidPublisherAuthException implements Exception {
  final String message;
  const AndroidPublisherAuthException(this.message);

  @override
  String toString() => 'AndroidPublisherAuthException($message)';
}

/// Google Play Developer API(androidpublisher) 実接続クライアント。
///
/// 認証はサービスアカウントのJWT Bearer方式(OAuth2)。
/// 1. サービスアカウントJSON内のprivate_keyでRS256署名したJWTを
///    https://oauth2.googleapis.com/token へPOSTし、アクセストークンを取得
///    (scope: https://www.googleapis.com/auth/androidpublisher)。
/// 2. アクセストークンをBearerとして androidpublisher API を呼び出す。
///
/// 審査状態の取得は「Edit」を1つ作成し、productionトラックのreleasesを
/// 見て最新リリースのstatusを見る、という手順になる(androidpublisher仕様上、
/// トラック情報の閲覧にも一時的なEditの作成が必要)。作成したEditは明示的な
/// コミット/削除を行わない(未コミットのEditは一定時間で自動的に破棄される
/// ため実害はない。参考: Google Play Developer API ドキュメント)。
///
/// 注意: Play Developer APIには「releaseの状態」を表すstatus
/// (draft/inProgress/halted/completed)はあるが、Appleの審査状態のような
/// 「ポリシー審査中/リジェクト」を明示するフィールドは公式には無い。
/// そのためreleaseのstatusを審査状態の近似値として扱っている。
class AndroidPublisherApiClient {
  AndroidPublisherApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _apiBaseUrl =
      'https://androidpublisher.googleapis.com/androidpublisher/v3';
  static const _scope = 'https://www.googleapis.com/auth/androidpublisher';

  Future<ReviewStatusSnapshot?> fetchLatestReviewStatus({
    required String serviceAccountJson,
    required String packageName,
    required String connectedAppId,
  }) async {
    final accessToken = await _fetchAccessToken(serviceAccountJson);

    final editId = await _insertEdit(packageName, accessToken);
    final tracks = await _listTracks(packageName, editId, accessToken);

    // production優先、無ければ他のトラックの中で最新のreleaseを持つものを見る。
    final track = tracks.firstWhere(
      (t) => t['track'] == 'production',
      orElse: () => tracks.isEmpty ? const {} : tracks.first,
    );
    final releases = (track['releases'] as List<dynamic>?) ?? const [];
    if (releases.isEmpty) return null;

    final release = releases.first as Map<String, dynamic>;
    final status = release['status'] as String?;
    final name = release['name'] as String?;
    final versionCodes = (release['versionCodes'] as List<dynamic>?)?.join(', ');

    return ReviewStatusSnapshot(
      id: '${connectedAppId}_play_latest',
      connectedAppId: connectedAppId,
      versionString: name ?? versionCodes ?? '',
      statusType: _mapTrackReleaseStatus(status),
      fetchedAt: DateTime.now(),
    );
  }

  // JWT組み立て〜oauth2/tokenへのPOSTはPlayDeveloperReportingApiClientと
  // 完全に共通の手順のため、google_service_account_oauth.dartへ切り出してある
  // (詳細な手順のコメントはそちらを参照)。
  Future<String> _fetchAccessToken(String serviceAccountJson) =>
      fetchGoogleServiceAccountAccessToken(
        serviceAccountJson: serviceAccountJson,
        scope: _scope,
        httpClient: _httpClient,
        exceptionBuilder: (message) => AndroidPublisherAuthException(message),
      );

  Future<String> _insertEdit(String packageName, String accessToken) async {
    final uri = Uri.parse('$_apiBaseUrl/applications/$packageName/edits');
    final http.Response response;
    try {
      response = await _httpClient
          .post(uri, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AndroidPublisherAuthException('Play Developer APIへの接続に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw AndroidPublisherAuthException(
        'Editの作成に失敗しました(HTTP ${response.statusCode})。'
        'パッケージ名とサービスアカウントの権限を確認してください。',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final editId = body['id'] as String?;
    if (editId == null || editId.isEmpty) {
      throw const AndroidPublisherAuthException('Edit作成の応答形式が不正です');
    }
    return editId;
  }

  Future<List<Map<String, dynamic>>> _listTracks(
    String packageName,
    String editId,
    String accessToken,
  ) async {
    final uri =
        Uri.parse('$_apiBaseUrl/applications/$packageName/edits/$editId/tracks');
    final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AndroidPublisherAuthException('Play Developer APIへの接続に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw AndroidPublisherAuthException(
        'トラック情報の取得に失敗しました(HTTP ${response.statusCode})',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tracks = (body['tracks'] as List<dynamic>?) ?? const [];
    return tracks.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  /// TrackReleaseのstatus(draft/inProgress/halted/completed)を、
  /// このアプリの5値のReviewStatusTypeへ近似的にマッピングする。
  /// Play Developer APIにはAppleのような明示的な「ポリシー審査中」
  /// フィールドが無いため、リリースの進行状況を審査状態の代理として扱う。
  ReviewStatusType _mapTrackReleaseStatus(String? status) => switch (status) {
        'draft' => ReviewStatusType.waitingReview,
        'inProgress' => ReviewStatusType.inReview,
        'halted' => ReviewStatusType.rejected,
        'completed' => ReviewStatusType.live,
        _ => ReviewStatusType.waitingReview,
      };
}
