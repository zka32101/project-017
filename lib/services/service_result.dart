/// Service層の統一戻り値。成功/失敗を明示し、UI側で握りつぶさせない。
/// 設計書 Step5「タイムアウト10秒・リトライ3回」の失敗系はこの型で表現する。
sealed class ServiceResult<T> {
  const ServiceResult();
}

class ServiceSuccess<T> extends ServiceResult<T> {
  final T data;
  const ServiceSuccess(this.data);
}

/// 失敗の種類。UI側（BuildContextを持つWidget）がこれを見てAppLocalizations経由の
/// メッセージへ変換する。Service層は自然文の日本語メッセージを直接保持しない
/// （Service/Notifier層にBuildContextが無く多言語化できないため）。
enum ServiceFailureReason {
  reviewStatus,
  rejectionDetails,
  buildFailureLogs,
  revenueSummary,
  appDiscovery,
  crashSummaries,
}

class ServiceFailure<T> extends ServiceResult<T> {
  final ServiceFailureReason reason;
  final Object? cause;
  const ServiceFailure(this.reason, {this.cause});
}

/// ServiceFailure を FutureProvider の例外として伝播させるためのラッパー。
/// これを投げることで AsyncValue が正しく AsyncError になり、UI側の
/// `.when(error: ...)` 分岐や initialScanProvider のリトライ導線が実際に機能する
/// （握りつぶして空リストを返すと、通信失敗と「データが本当に無い」状態が区別できない）。
class ServiceFailureException implements Exception {
  final ServiceFailure<dynamic> failure;
  const ServiceFailureException(this.failure);

  ServiceFailureReason get reason => failure.reason;

  @override
  String toString() => 'ServiceFailureException(${failure.reason})';
}

/// FutureProvider群がServiceResultを「成功ならデータ、失敗なら
/// ServiceFailureExceptionとして投げる」というAsyncValue向けの形へ揃えて
/// 取り出すための共通ヘルパー。各providerが同じswitch式を個別に書いていた
/// ものを1箇所にまとめる。
extension ServiceResultUnwrap<T> on ServiceResult<T> {
  T unwrap() => switch (this) {
        ServiceSuccess<T>(:final data) => data,
        ServiceFailure<T> failure => throw ServiceFailureException(failure),
      };
}

/// Service層の各メソッドが繰り返し書いていた
/// 「try { データを取得してServiceSuccessで包む } catch (e) {
/// ServiceFailure(reason, cause: e)を返す }」という定型処理をまとめる。
/// AppStoreConnectService/PlayConsoleServiceの各メソッド本体は、実際の
/// データ取得処理(body)だけを渡せばよくなる。
/// cause フィールドは現状どこからも読まれないため(UI側は reason だけを見て
/// ローカライズ済みメッセージへ変換する)、body内で早期リターンの代わりに
/// 例外を投げても表示上の挙動は変わらない。
Future<ServiceResult<T>> guardServiceCall<T>(
  ServiceFailureReason reason,
  Future<T> Function() body,
) async {
  try {
    return ServiceSuccess(await body());
  } catch (e) {
    return ServiceFailure<T>(reason, cause: e);
  }
}
