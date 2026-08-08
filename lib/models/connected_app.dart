import 'platform_type.dart';

/// ConnectedApp { id, userId, platform, bundleId/packageName,
///   appStoreConnectKeyRef/playConsoleKeyRef(Keychain参照のみ), displayName, sortOrder }
///
/// 重要: keyRef は Keychain/EncryptedSharedPreferences の参照キー文字列のみを保持する。
/// APIキー本体は絶対にこのモデル・Firestoreに保存しない（設計書 Step5 二重防御）。
class ConnectedApp {
  final String id;
  final String userId;
  final PlatformType platform;
  final String bundleIdOrPackageName;
  final String? apiKeyRef;
  final String displayName;
  final int sortOrder;

  const ConnectedApp({
    required this.id,
    required this.userId,
    required this.platform,
    required this.bundleIdOrPackageName,
    this.apiKeyRef,
    required this.displayName,
    required this.sortOrder,
  });

  bool get hasApiKeyRegistered => apiKeyRef != null && apiKeyRef!.isNotEmpty;

  ConnectedApp copyWith({
    String? apiKeyRef,
    String? displayName,
    int? sortOrder,
  }) =>
      ConnectedApp(
        id: id,
        userId: userId,
        platform: platform,
        bundleIdOrPackageName: bundleIdOrPackageName,
        apiKeyRef: apiKeyRef ?? this.apiKeyRef,
        displayName: displayName ?? this.displayName,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  factory ConnectedApp.fromJson(Map<String, dynamic> json) => ConnectedApp(
        id: json['id'] as String,
        userId: json['userId'] as String,
        platform: PlatformType.values.firstWhere(
          (e) => e.name == json['platform'],
        ),
        bundleIdOrPackageName: json['bundleIdOrPackageName'] as String,
        apiKeyRef: json['apiKeyRef'] as String?,
        displayName: json['displayName'] as String,
        sortOrder: json['sortOrder'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'platform': platform.name,
        'bundleIdOrPackageName': bundleIdOrPackageName,
        'apiKeyRef': apiKeyRef,
        'displayName': displayName,
        'sortOrder': sortOrder,
      };
}
