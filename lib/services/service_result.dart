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
