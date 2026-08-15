import '../models/connected_app.dart';
import '../models/revenue_summary.dart';
import 'service_result.dart';

/// 売上・DL数サマリー（Should機能、設計書 Step4: RevenueCat API連携）。
/// MVP段階はRevenueCat SDK/API未接続のため、モックデータを返す。
/// 実接続時は fetchRevenueSummary() の内部実装のみ置き換える（他Serviceと同じ差し替え方針）。
class RevenueCatService {
  const RevenueCatService();

  Future<ServiceResult<List<RevenueSummary>>> fetchRevenueSummary(
    ConnectedApp app, {
    int days = 30,
  }) async {
    try {
      final now = DateTime(2026, 8, 5);
      final data = List.generate(days, (i) {
        final date = now.subtract(Duration(days: days - 1 - i));
        // 単純な右肩上がりの疑似データ（実データ接続までのUI検証用）
        final baseRevenue = 800.0 + i * 12.0;
        final baseDownloads = 15 + (i % 5);
        return RevenueSummary(
          id: '${app.id}_rev_$i',
          connectedAppId: app.id,
          date: date,
          revenue: baseRevenue,
          downloadCount: baseDownloads,
        );
      });
      return ServiceSuccess(data);
    } catch (e) {
      return ServiceFailure(ServiceFailureReason.revenueSummary, cause: e);
    }
  }
}
