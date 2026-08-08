import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/build_failure_log.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/rejection_detail.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/export_service.dart';

void main() {
  const app = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    displayName: 'テストアプリ',
    sortOrder: 0,
  );

  group('ExportService.buildCsv', () {
    test('各セクションの見出しと件数分の行が出力される', () {
      final history = [
        ReviewStatusSnapshot(
          id: 's1',
          connectedAppId: app.id,
          versionString: '1.0.0',
          statusType: ReviewStatusType.live,
          fetchedAt: DateTime(2026, 8, 1),
        ),
      ];
      final rejections = [
        RejectionDetail(
          id: 'r1',
          reviewStatusSnapshotId: 's1',
          connectedAppId: app.id,
          guidelineNumber: '2.3.1',
          guidelineTitle: 'Accurate Metadata',
          resolutionCenterMessage: 'テスト用メッセージ',
          rejectedAt: DateTime(2026, 7, 20),
        ),
      ];
      final buildFailures = [
        BuildFailureLog(
          id: 'b1',
          connectedAppId: app.id,
          buildNumber: '42',
          platform: PlatformType.ios,
          failureReason: 'Missing entitlement',
          occurredAt: DateTime(2026, 7, 15),
        ),
      ];

      const service = ExportService();
      final csv = service.buildCsv(app, history, rejections, buildFailures);

      expect(csv, contains('テストアプリ'));
      expect(csv, contains('審査履歴'));
      expect(csv, contains('1.0.0'));
      expect(csv, contains('リジェクト理由'));
      expect(csv, contains('2.3.1'));
      expect(csv, contains('ビルド失敗ログ'));
      expect(csv, contains('Missing entitlement'));
    });

    test('データが空でも見出し行のみで例外を投げない', () {
      const service = ExportService();
      final csv = service.buildCsv(app, [], [], []);
      expect(csv, contains('審査履歴'));
      expect(csv, isNotEmpty);
    });
  });
}
