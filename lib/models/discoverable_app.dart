/// App Store Connect / Play Console のAPIキー1つに紐づく「アカウント配下の
/// アプリ一覧取得」の結果1件分。まとめて取得（一括登録）フローで、
/// ConnectedAppsNotifier.registerAppsBulk() へそのまま渡す入力になる。
///
/// ConnectedApp と違い、id・sortOrder・apiKeyRef 等のローカル管理用フィールドは
/// 持たない（それらは登録時にConnectedAppsNotifier側で採番される）。
class DiscoverableApp {
  final String bundleIdOrPackageName;
  final String displayName;

  const DiscoverableApp({
    required this.bundleIdOrPackageName,
    required this.displayName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverableApp &&
          runtimeType == other.runtimeType &&
          bundleIdOrPackageName == other.bundleIdOrPackageName &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(bundleIdOrPackageName, displayName);
}
