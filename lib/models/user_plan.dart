/// 課金プラン（フリーミアム: 無料=2アプリまで／有料=無制限）
enum UserPlan {
  free,
  pro;

  /// 無料プランの登録可能アプリ数上限（Remote Configで上書き想定、初期値）
  static const int freeAppLimit = 2;
}
