import '../models/build_failure_log.dart';
import '../models/crash_summary.dart';
import '../models/platform_type.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import '../models/review_status_type.dart';

/// ドッグフーディング用モックデータ（条件3: petit.works既存タイトルを初期登録アプリとして活用）。
/// 実API接続（Webhooks/Play Developer API）が未実装のMVP段階で、
/// Aha Moment動線（アプリ登録→初回スキャン→ダッシュボード）を検証するために使用する。
class MockDataService {
  const MockDataService();

  List<ReviewStatusSnapshot> reviewStatusesFor(
    String connectedAppId,
    PlatformType platform,
  ) {
    final now = DateTime(2026, 8, 5);
    if (platform == PlatformType.ios) {
      return [
        ReviewStatusSnapshot(
          id: '${connectedAppId}_snap1',
          connectedAppId: connectedAppId,
          versionString: '1.4.0',
          statusType: ReviewStatusType.inReview,
          fetchedAt: now,
        ),
      ];
    }
    return [
      ReviewStatusSnapshot(
        id: '${connectedAppId}_snap1',
        connectedAppId: connectedAppId,
        versionString: '2.1.0',
        statusType: ReviewStatusType.live,
        fetchedAt: now,
      ),
    ];
  }

  List<RejectionDetail> rejectionsFor(String connectedAppId) => [];

  List<BuildFailureLog> buildFailuresFor(
    String connectedAppId,
    PlatformType platform,
  ) =>
      [];

  List<CrashSummary> crashSummariesFor(String connectedAppId) {
    final now = DateTime(2026, 8, 5);
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return CrashSummary(
        id: '${connectedAppId}_crash_$i',
        connectedAppId: connectedAppId,
        date: date,
        crashFreeRate: 99.6,
        crashCount: 2,
      );
    });
  }
}
