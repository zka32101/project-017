/// ドッグフーディング用デモアプリの固定ID。
///
/// ConnectedAppsNotifier がこの固定IDでデモアプリを自動登録する（実際の
/// API認証情報は持たず、ダミーの文字列のみ）。Service層（AppStoreConnectService/
/// PlayConsoleService）はこのIDのアプリに対しては実APIを呼び出さず、
/// 常にMockDataServiceのデータを返す。viewmodels層・services層の両方から
/// 参照されるため、レイヤー間の依存を作らないよう独立したファイルに置く。
const String demoIosAppId = 'demo-app-ios';
const String demoAndroidAppId = 'demo-app-android';

/// 指定のIDがいずれかのデモアプリのものかどうか。Service層の各メソッドが
/// `id == demoIosAppId`のように個別に比較するのではなくここを参照することで、
/// 将来デモアプリの種類が増えてもこの1箇所を直すだけで済むようにする。
bool isDemoAppId(String id) => id == demoIosAppId || id == demoAndroidAppId;
