import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// APIキー・トークンのオンデバイス保管（Must#4、設計書 Step5 二重防御のクライアント側）。
/// iOS: Keychain / Android: EncryptedSharedPreferences（flutter_secure_storageが自動選択）。
/// 保存する値は「参照キー文字列」ではなく、実際のAPIキー本体そのもの。
/// ConnectedApp モデル側は参照キー（refKey）のみを保持し、本体はここにしか存在しない。
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static String refKeyFor(String connectedAppId) => 'apikey_$connectedAppId';

  Future<void> saveApiKey({
    required String connectedAppId,
    required String apiKey,
  }) =>
      _storage.write(key: refKeyFor(connectedAppId), value: apiKey);

  Future<String?> readApiKey(String connectedAppId) =>
      _storage.read(key: refKeyFor(connectedAppId));

  Future<void> deleteApiKey(String connectedAppId) =>
      _storage.delete(key: refKeyFor(connectedAppId));

  /// ConnectedApp単位ではなく、アプリ全体で1つだけ保持する値（RevenueCat
  /// OAuthクライアント情報・トークン等）向けの汎用read/write/delete。
  /// キーの衝突を避けるため、呼び出し側は`revenuecat_`のような専用の
  /// プレフィックスを付けること（apikey_*と被らなければ何でもよい）。
  Future<void> writeValue({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  Future<String?> readValue(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);
}
