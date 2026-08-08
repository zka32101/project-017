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
