import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/revenue_summary.dart';
import 'package:ririkan/services/revenue_cat_service.dart';
import 'package:ririkan/services/service_result.dart';

void main() {
  const app = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    displayName: 'テストアプリ',
    sortOrder: 0,
  );

  group('RevenueCatService.fetchRevenueSummary', () {
    test('指定日数分のデータが日付昇順で返る', () async {
      const service = RevenueCatService();
      final result = await service.fetchRevenueSummary(app, days: 7);

      expect(result, isA<ServiceSuccess<List<RevenueSummary>>>());
      final data = (result as ServiceSuccess<List<RevenueSummary>>).data;
      expect(data.length, 7);
      for (var i = 1; i < data.length; i++) {
        expect(data[i].date.isAfter(data[i - 1].date), isTrue);
      }
      expect(data.every((r) => r.connectedAppId == app.id), isTrue);
    });

    test('デフォルトは30日分のデータを返す', () async {
      const service = RevenueCatService();
      final result = await service.fetchRevenueSummary(app);
      final data = (result as ServiceSuccess<List<RevenueSummary>>).data;
      expect(data.length, 30);
    });
  });
}
