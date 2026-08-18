import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'secure_storage_service.dart';

/// RevenueCat OAuth連携の認証・通信失敗を表す例外。
class RevenueCatAuthException implements Exception {
  final String message;
  const RevenueCatAuthException(this.message);

  @override
  String toString() => 'RevenueCatAuthException($message)';
}

/// システムブラウザでのOAuth認可コードフロー実行を担う薄いラッパー。
/// flutter_web_auth_2はプラットフォームチャネル経由でネイティブのブラウザ/
/// ASWebAuthenticationSessionを呼び出すため、flutter test環境では直接
/// 動作しない。テストではこのインターフェースをフェイクへ差し替える。
abstract class WebAuthLauncher {
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  });
}

class FlutterWebAuthLauncher implements WebAuthLauncher {
  const FlutterWebAuthLauncher();

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
  }) =>
      FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );
}

/// RevenueCatServiceが依存する認証手段の抽象。RevenueCatOAuthServiceの
/// 実際のOAuthフロー(ブラウザ起動・トークン交換)を伴わずにテストできるよう、
/// テストでは軽量なフェイクへ差し替える(他Serviceのインターフェース分離と
/// 同じ方針)。
abstract class RevenueCatAuthProvider {
  Future<bool> isConnected();
  Future<String> getValidAccessToken();
}

/// RevenueCat連携（売上・DL数、Should機能）: Charts & Metrics API
/// (GET /v2/projects/{id}/metrics/overview, GET /v2/projects/{id}/charts/{name})
/// は、他のRevenueCat REST APIで使うシークレットキー(sk_...)ではなく、
/// OAuth 2.0のアクセストークン(charts_metrics:* スコープ付き)が必要。
/// そのためApp Store Connect/Play Consoleのような「キーを1回貼り付ける」
/// 認証パターンではなく、Authorization Code + PKCE(RFC 7636)による
/// システムブラウザでのユーザー同意フローが必要になる。
///
/// 【重要な注意】api.revenuecat.com / revenuecat.com はこの開発環境の
/// ネットワークegressポリシーでブロックされており実機での動作検証ができて
/// いない。認可エンドポイント(/oauth2/authorize)・トークンエンドポイント
/// (/oauth2/token)・必要スコープ名は、RevenueCat公式ドキュメントを直接
/// 参照できなかったため、検索結果から得た二次情報とOAuth 2.0の一般的な
/// 規約から構成した最善推定であり、実際のRevenueCat OAuthアプリでの
/// 動作確認が別途必要(エンドポイントパスやスコープ名が実際と異なる場合、
/// 要修正)。
///
/// clientId/clientSecretはRevenueCatダッシュボードの
/// Project Settings > API Keys でOAuthアプリを作成して取得し、
/// リダイレクトURIには `ririkan://revenuecat-oauth-callback` を登録する
/// 必要がある(AndroidManifest.xmlのCallbackActivityで受け取る独自スキーム)。
class RevenueCatOAuthService implements RevenueCatAuthProvider {
  RevenueCatOAuthService({
    required SecureStorageService secureStorageService,
    WebAuthLauncher? webAuthLauncher,
    http.Client? httpClient,
  })  : _secureStorage = secureStorageService,
        _webAuth = webAuthLauncher ?? const FlutterWebAuthLauncher(),
        _httpClient = httpClient ?? http.Client();

  final SecureStorageService _secureStorage;
  final WebAuthLauncher _webAuth;
  final http.Client _httpClient;

  static const _authorizationEndpoint =
      'https://api.revenuecat.com/oauth2/authorize';
  static const _tokenEndpoint = 'https://api.revenuecat.com/oauth2/token';
  static const _callbackUrlScheme = 'ririkan';
  static const _redirectUri = 'ririkan://revenuecat-oauth-callback';
  static const _scope = 'charts_metrics:overview:read charts_metrics:charts:read';

  // 保存キー(SecureStorageService.writeValue/readValue/deleteValue経由)。
  static const _keyClientId = 'revenuecat_oauth_client_id';
  static const _keyClientSecret = 'revenuecat_oauth_client_secret';
  static const _keyAccessToken = 'revenuecat_oauth_access_token';
  static const _keyRefreshToken = 'revenuecat_oauth_refresh_token';
  static const _keyExpiresAt = 'revenuecat_oauth_expires_at';

  /// 接続済み(リフレッシュトークンを保持している)かどうか。
  @override
  Future<bool> isConnected() async {
    final refreshToken = await _secureStorage.readValue(_keyRefreshToken);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  /// RevenueCatダッシュボードで作成したOAuthアプリのclient_id/client_secretを
  /// 使い、システムブラウザでの認可コードフロー(PKCE付き)を開始する。
  /// ユーザーがRevenueCat側の同意画面で許可すると、独自スキームへの
  /// リダイレクトをflutter_web_auth_2が捕捉してこの関数へ返す。
  Future<void> connect({
    required String clientId,
    required String clientSecret,
  }) async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeFor(verifier);
    final state = _generateCodeVerifier();

    final authUrl = Uri.parse(_authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': _redirectUri,
        'scope': _scope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    final String redirectResult;
    try {
      redirectResult = await _webAuth.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackUrlScheme,
      );
    } catch (e) {
      throw RevenueCatAuthException('認可画面の表示、またはキャンセルにより失敗しました: $e');
    }

    final redirectUri = Uri.parse(redirectResult);
    final error = redirectUri.queryParameters['error'];
    if (error != null) {
      throw RevenueCatAuthException('RevenueCat側で認可が拒否されました: $error');
    }
    final returnedState = redirectUri.queryParameters['state'];
    if (returnedState != state) {
      throw const RevenueCatAuthException('stateが一致しません(CSRF対策により中断)');
    }
    final code = redirectUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const RevenueCatAuthException('認可コードが取得できませんでした');
    }

    await _exchangeToken(
      clientId: clientId,
      clientSecret: clientSecret,
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': clientId,
        'client_secret': clientSecret,
        'code_verifier': verifier,
      },
    );

    await _secureStorage.writeValue(key: _keyClientId, value: clientId);
    await _secureStorage.writeValue(key: _keyClientSecret, value: clientSecret);
  }

  /// 接続情報(client_id/client_secret含む)を全て削除する。
  Future<void> disconnect() async {
    await _secureStorage.deleteValue(_keyClientId);
    await _secureStorage.deleteValue(_keyClientSecret);
    await _secureStorage.deleteValue(_keyAccessToken);
    await _secureStorage.deleteValue(_keyRefreshToken);
    await _secureStorage.deleteValue(_keyExpiresAt);
  }

  /// 有効なアクセストークンを返す。期限切れ(または期限間近)ならリフレッシュ
  /// トークンで更新してから返す。未接続ならRevenueCatAuthExceptionを投げる。
  @override
  Future<String> getValidAccessToken() async {
    final accessToken = await _secureStorage.readValue(_keyAccessToken);
    final expiresAtStr = await _secureStorage.readValue(_keyExpiresAt);
    final expiresAt = expiresAtStr == null ? null : DateTime.tryParse(expiresAtStr);

    final needsRefresh = accessToken == null ||
        accessToken.isEmpty ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 1)));

    if (!needsRefresh) return accessToken;

    final refreshToken = await _secureStorage.readValue(_keyRefreshToken);
    final clientId = await _secureStorage.readValue(_keyClientId);
    final clientSecret = await _secureStorage.readValue(_keyClientSecret);
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        clientId == null ||
        clientSecret == null) {
      throw const RevenueCatAuthException('RevenueCatと未接続です');
    }

    // リフレッシュ時、古いアクセストークン・リフレッシュトークンはRevenueCat側で
    // 失効し新しいものが発行される(ローテーション)ため、返ってきた値で
    // 保存内容を必ず上書きする。
    return _exchangeToken(
      clientId: clientId,
      clientSecret: clientSecret,
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );
  }

  Future<String> _exchangeToken({
    required String clientId,
    required String clientSecret,
    required Map<String, String> body,
  }) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(Uri.parse(_tokenEndpoint), body: body)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw RevenueCatAuthException('RevenueCatの認証サーバーへの接続に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw RevenueCatAuthException(
        'トークンの取得に失敗しました(HTTP ${response.statusCode})。'
        'client_id/client_secret、またはRevenueCat側のOAuthアプリ設定を確認してください。',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const RevenueCatAuthException('トークンレスポンスの形式が不正です');
    }
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    final expiresIn = json['expires_in'] as int?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const RevenueCatAuthException('トークンレスポンスにaccess_tokenが含まれていません');
    }

    await _secureStorage.writeValue(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.writeValue(key: _keyRefreshToken, value: refreshToken);
    }
    final expiresAt =
        DateTime.now().add(Duration(seconds: expiresIn ?? 3600));
    await _secureStorage.writeValue(
      key: _keyExpiresAt,
      value: expiresAt.toIso8601String(),
    );

    return accessToken;
  }

  static const _unreservedChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// RFC 7636準拠のcode_verifier(43〜128文字のunreserved characters)を
  /// ランダム生成する。Random.secureを使い、暗号論的に安全な乱数を確保する。
  String _generateCodeVerifier() {
    final random = Random.secure();
    return List.generate(
      64,
      (_) => _unreservedChars[random.nextInt(_unreservedChars.length)],
    ).join();
  }

  /// code_challenge = BASE64URL-ENCODE(SHA256(code_verifier))、パディング無し。
  String _codeChallengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
