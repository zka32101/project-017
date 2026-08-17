import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import '../models/discoverable_app.dart';

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
  /// 1ページ目（最大200件）のみ取得する（MVP範囲、201件超の場合は次フェーズでページネーション対応）。
  Future<List<DiscoverableApp>> listApps(String credentialJson) async {
    final creds = _parseCredential(credentialJson);
    final token = _buildJwt(
      issuerId: creds.issuerId,
      keyId: creds.keyId,
      privateKeyPem: creds.privateKey,
    );

    final uri = Uri.parse('$_baseUrl/apps?limit=200');
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

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw AppStoreConnectAuthException('App Store Connect APIの応答を解析できませんでした: $e');
    }

    final data = (body['data'] as List<dynamic>?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_toDiscoverableApp)
        .whereType<DiscoverableApp>()
        .toList();
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
