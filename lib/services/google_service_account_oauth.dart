import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

/// Googleサービスアカウント(JWT Bearer方式、RFC 7523)によるOAuth2アクセストークン取得。
///
/// androidpublisher(AndroidPublisherApiClient)とplaydeveloperreporting
/// (PlayDeveloperReportingApiClient)の両方が、スコープ以外はまったく同じ手順
/// (サービスアカウントJSON解析→RS256署名JWT組み立て→oauth2/tokenへPOST)を
/// 必要とするため、ここに共通化する。例外の型はAPIクライアントごとに異なる
/// (呼び出し元のServiceFailureReasonに合わせて別々の型を投げ分けている)ため、
/// 実際の例外の生成だけは呼び出し元へコールバックで委譲する。
Future<String> fetchGoogleServiceAccountAccessToken({
  required String serviceAccountJson,
  required String scope,
  required http.Client httpClient,
  required Exception Function(String message) exceptionBuilder,
}) async {
  const oauthTokenUrl = 'https://oauth2.googleapis.com/token';

  final Map<String, dynamic> creds;
  try {
    creds = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
  } catch (e) {
    throw exceptionBuilder('サービスアカウントJSONキーの形式が不正です');
  }
  final clientEmail = creds['client_email'] as String?;
  final privateKeyPem = creds['private_key'] as String?;
  if (clientEmail == null ||
      clientEmail.isEmpty ||
      privateKeyPem == null ||
      privateKeyPem.isEmpty) {
    throw exceptionBuilder(
      'サービスアカウントJSONキーに client_email / private_key が含まれていません',
    );
  }

  final RSAPrivateKey key;
  try {
    key = RSAPrivateKey(privateKeyPem);
  } catch (e) {
    throw exceptionBuilder('サービスアカウントの秘密鍵の形式が不正です: $e');
  }

  // scopeはJWT標準クレームではないため、payload(カスタムクレーム)として
  // 直接含める(OAuth2 JWT Bearer Token Flowの仕様、RFC 7523)。
  final jwt = JWT(
    {'scope': scope},
    issuer: clientEmail,
    subject: clientEmail,
    audience: Audience.one(oauthTokenUrl),
  );
  final signed = jwt.sign(
    key,
    algorithm: JWTAlgorithm.RS256,
    expiresIn: const Duration(hours: 1),
  );

  final http.Response response;
  try {
    response = await httpClient.post(
      Uri.parse(oauthTokenUrl),
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': signed,
      },
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    throw exceptionBuilder('Googleの認証サーバーへの接続に失敗しました: $e');
  }

  if (response.statusCode != 200) {
    throw exceptionBuilder(
      'アクセストークンの取得に失敗しました(HTTP ${response.statusCode})。'
      'サービスアカウントJSONキーの内容と権限を確認してください。',
    );
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final token = body['access_token'] as String?;
  if (token == null || token.isEmpty) {
    throw exceptionBuilder('アクセストークンの応答形式が不正です');
  }
  return token;
}
