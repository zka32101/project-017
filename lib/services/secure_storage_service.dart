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
}
