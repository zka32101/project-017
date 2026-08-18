import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import '../models/discoverable_app.dart';
import '../models/review_status_snapshot.dart';
import '../models/review_status_type.dart';

/// App Store Connect APIへの認証・通信失敗を表す例外。
/// メッセージは開発者向けの詳細情報であり、UI側は
/// ServiceFailureReason.appDiscovery を経由してローカライズ済み
/// メッセージへ変換するため、そのまま画面表示はしない。
class AppStoreConnectAuthException implements Exception {
  final String message;
  const AppStoreConnectAuthException(this.message);

  @override
  String toString() => 'AppStoreConnectAuthException($message)';
}

/// App Store Connect API 実接続クライアント。
///
/// 認証はApple公式のJWT(ES256)方式（参考: Generating Tokens for API Requests
/// https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests）。
/// - header: alg=ES256, kid=（Key ID）
/// - payload: iss=（Issuer ID）, iat=現在時刻, exp=iat+最大20分, aud=appstoreconnect-v1
/// - 秘密鍵: 発行された.p8ファイルの中身（PEM形式のEC秘密鍵）でES256署名
///
/// discoverApps() の apiKey 引数には、この3情報をまとめたJSON文字列
/// {"issuerId": "...", "keyId": "...", "privateKey": "-----BEGIN PRIVATE KEY-----..."}
/// を渡す想定（AppRegistrationScreen側で3つの入力欄からJSON化する）。
class AppStoreConnectApiClient {
  AppStoreConnectApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _baseUrl = 'https://api.appstoreconnect.apple.com/v1';

  /// GET /v1/apps でアカウント配下の全アプリを取得する。
  /// App Store Connect APIはJSON:API準拠のカーソルページネーション
  /// (`links.next`に次ページの完全なURLが入る、無ければ最終ページ)を採用しており、
  /// `links.next`が無くなるまで辿って全件取得する（201件超のアカウントにも対応）。
  /// 暴走防止のため最大50ページ(=最大1万件)で打ち切る。
  Future<List<DiscoverableApp>> listApps(String credentialJson) async {
    final token = _buildJwtFromCredentialJson(credentialJson);

    final apps = <DiscoverableApp>[];
    Uri? uri = Uri.parse('$_baseUrl/apps?limit=200');
    var pageCount = 0;
    while (uri != null && pageCount < 50) {
      pageCount++;
      final body = await _getJson(uri, token);

      final data = (body['data'] as List<dynamic>?) ?? const [];
      apps.addAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(_toDiscoverableApp)
            .whereType<DiscoverableApp>(),
      );

      final links = body['links'] as Map<String, dynamic>?;
      final next = links?['next'] as String?;
      uri = (next == null || next.isEmpty) ? null : Uri.parse(next);
    }
    return apps;
  }

  /// アプリの最新バージョンの審査状態を取得する（GET /v1/apps?filter[bundleId]=
  /// でASC内部idを引き、GET /v1/apps/{id}/appStoreVersions で最新バージョンの
  /// appStoreStateを見る）。該当アプリ・バージョンが1件も無い場合はnullを返す。
  Future<ReviewStatusSnapshot?> fetchLatestReviewStatus({
    required String credentialJson,
    required String bundleId,
    required String connectedAppId,
  }) async {
    final token = _buildJwtFromCredentialJson(credentialJson);

    final ascAppId = await _findAppId(bundleId: bundleId, token: token);
    if (ascAppId == null) return null;

    final uri = Uri.parse('$_baseUrl/apps/$ascAppId/appStoreVersions?limit=10');
    final body = await _getJson(uri, token);
    final data = (body['data'] as List<dynamic>?) ?? const [];
    final versions = data.whereType<Map<String, dynamic>>().toList()
      // createdDateの新しい順に並べる(APIのデフォルト順に依存しないため)。
      ..sort((a, b) {
        final aDate = (a['attributes'] as Map<String, dynamic>?)?['createdDate'] as String?;
        final bDate = (b['attributes'] as Map<String, dynamic>?)?['createdDate'] as String?;
        return (bDate ?? '').compareTo(aDate ?? '');
      });
    if (versions.isEmpty) return null;

    final attrs = versions.first['attributes'] as Map<String, dynamic>?;
    final versionString = attrs?['versionString'] as String? ?? '';
    final appStoreState = attrs?['appStoreState'] as String?;

    return ReviewStatusSnapshot(
      id: '${connectedAppId}_asc_latest',
      connectedAppId: connectedAppId,
      versionString: versionString,
      statusType: _mapAppStoreState(appStoreState),
      fetchedAt: DateTime.now(),
    );
  }

  Future<String?> _findAppId({required String bundleId, required String token}) async {
    final uri = Uri.parse(
      '$_baseUrl/apps?filter%5BbundleId%5D=${Uri.encodeQueryComponent(bundleId)}&limit=1',
    );
    final body = await _getJson(uri, token);
    final data = (body['data'] as List<dynamic>?) ?? const [];
    if (data.isEmpty) return null;
    return (data.first as Map<String, dynamic>?)?['id'] as String?;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String token) async {
    final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AppStoreConnectAuthException('App Store Connect APIへの接続に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw AppStoreConnectAuthException(
        'App Store Connect APIがエラーを返しました(HTTP ${response.statusCode})。'
        'Issuer ID / Key ID / 秘密鍵の内容と権限スコープを確認してください。',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw AppStoreConnectAuthException('App Store Connect APIの応答を解析できませんでした: $e');
    }
  }

  /// Apple公式ドキュメント「App and submission statuses」に載っている
  /// AppStoreVersionState(細かい状態)を、このアプリの5値の
  /// ReviewStatusType(審査待ち/審査中/リジェクト/承認済み/公開中)へ丸め込む。
  /// 参考: https://developer.apple.com/help/app-store-connect/reference/app-and-submission-statuses
  /// あくまで近似のマッピングであり、Apple側の状態遷移の全ニュアンスを
  /// 表現しきれるものではない。
  ReviewStatusType _mapAppStoreState(String? state) => switch (state) {
        'PREPARE_FOR_SUBMISSION' ||
        'READY_FOR_REVIEW' ||
        'INVALID_BINARY' ||
        'WAITING_FOR_REVIEW' =>
          ReviewStatusType.waitingReview,
        'IN_REVIEW' || 'PENDING_CONTRACT' => ReviewStatusType.inReview,
        'REJECTED' || 'METADATA_REJECTED' || 'DEVELOPER_REJECTED' =>
          ReviewStatusType.rejected,
        'READY_FOR_DISTRIBUTION' => ReviewStatusType.live,
        _ => ReviewStatusType.approved, // ACCEPTED/PENDING_DEVELOPER_RELEASE等、承認済み〜公開待ちの状態
      };

  String _buildJwtFromCredentialJson(String credentialJson) {
    final creds = _parseCredential(credentialJson);
    return _buildJwt(
      issuerId: creds.issuerId,
      keyId: creds.keyId,
      privateKeyPem: creds.privateKey,
    );
  }

  DiscoverableApp? _toDiscoverableApp(Map<String, dynamic> item) {
    final attrs = item['attributes'] as Map<String, dynamic>?;
    final bundleId = attrs?['bundleId'] as String?;
    if (bundleId == null || bundleId.isEmpty) return null;
    final name = attrs?['name'] as String?;
    return DiscoverableApp(
      bundleIdOrPackageName: bundleId,
      displayName: (name == null || name.isEmpty) ? bundleId : name,
    );
  }

  String _buildJwt({
    required String issuerId,
    required String keyId,
    required String privateKeyPem,
  }) {
    final ECPrivateKey key;
    try {
      key = ECPrivateKey(privateKeyPem);
    } catch (e) {
      throw AppStoreConnectAuthException('秘密鍵(.p8)の形式が不正です: $e');
    }

    final jwt = JWT(
      const <String, dynamic>{},
      issuer: issuerId,
      audience: Audience.one('appstoreconnect-v1'),
      header: {'kid': keyId},
    );

    try {
      // Appleの規定上、有効期限は発行から最大20分。少し余裕を持たせて15分にする。
      return jwt.sign(
        key,
        algorithm: JWTAlgorithm.ES256,
        expiresIn: const Duration(minutes: 15),
      );
    } catch (e) {
      throw AppStoreConnectAuthException('JWTの生成に失敗しました: $e');
    }
  }

  _AppStoreConnectCredential _parseCredential(String credentialJson) {
    final Map<String, dynamic> raw;
    try {
      raw = jsonDecode(credentialJson) as Map<String, dynamic>;
    } catch (e) {
      throw const AppStoreConnectAuthException(
        '認証情報の形式が不正です(Issuer ID / Key ID / 秘密鍵が正しく入力されているか確認してください)',
      );
    }
    final issuerId = raw['issuerId'] as String?;
    final keyId = raw['keyId'] as String?;
    final privateKey = raw['privateKey'] as String?;
    if (issuerId == null ||
        issuerId.isEmpty ||
        keyId == null ||
        keyId.isEmpty ||
        privateKey == null ||
        privateKey.isEmpty) {
      throw const AppStoreConnectAuthException(
        'Issuer ID / Key ID / 秘密鍵のいずれかが未入力です',
      );
    }
    return _AppStoreConnectCredential(
      issuerId: issuerId,
      keyId: keyId,
      privateKey: privateKey,
    );
  }
}

class _AppStoreConnectCredential {
  final String issuerId;
  final String keyId;
  final String privateKey;
  const _AppStoreConnectCredential({
    required this.issuerId,
    required this.keyId,
    required this.privateKey,
  });
}
