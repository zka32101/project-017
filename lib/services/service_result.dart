/// Service層の統一戻り値。成功/失敗を明示し、UI側で握りつぶさせない。
/// 設計書 Step5「タイムアウト10秒・リトライ3回」の失敗系はこの型で表現する。
sealed class ServiceResult<T> {
  const ServiceResult();
}

class ServiceSuccess<T> extends ServiceResult<T> {
  final T data;
  const ServiceSuccess(this.data);
}

class ServiceFailure<T> extends ServiceResult<T> {
  final String message;
  final Object? cause;
  const ServiceFailure(this.message, {this.cause});
}

/// ServiceFailure を FutureProvider の例外として伝播させるためのラッパー。
/// これを投げることで AsyncValue が正しく AsyncError になり、UI側の
/// `.when(error: ...)` 分岐や initialScanProvider のリトライ導線が実際に機能する
/// （握りつぶして空リストを返すと、通信失敗と「データが本当に無い」状態が区別できない）。
class ServiceFailureException implements Exception {
  final ServiceFailure<dynamic> failure;
  const ServiceFailureException(this.failure);

  String get message => failure.message;

  @override
  String toString() => message;
}
