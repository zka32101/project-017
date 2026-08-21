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

  group('ExportService.buildCsvForAll', () {
    const app2 = ConnectedApp(
      id: 'app2',
      userId: 'u1',
      platform: PlatformType.android,
      bundleIdOrPackageName: 'works.petit.app2',
      displayName: 'テストアプリ2',
      sortOrder: 1,
    );

    test('アプリごとの見出しと各セクションが繰り返し出力される', () {
      final bundle1 = AppExportBundle(
        app: app,
        reviewHistory: [
          ReviewStatusSnapshot(
            id: 's1',
            connectedAppId: app.id,
            versionString: '1.0.0',
            statusType: ReviewStatusType.live,
            fetchedAt: DateTime(2026, 8, 1),
          ),
        ],
        rejections: const [],
        buildFailures: const [],
      );
      final bundle2 = AppExportBundle(
        app: app2,
        reviewHistory: [
          ReviewStatusSnapshot(
            id: 's2',
            connectedAppId: app2.id,
            versionString: '2.0.0',
            statusType: ReviewStatusType.inReview,
            fetchedAt: DateTime(2026, 8, 2),
          ),
        ],
        rejections: const [],
        buildFailures: const [],
      );

      const service = ExportService();
      final csv = service.buildCsvForAll([bundle1, bundle2]);

      expect(csv, contains('全アプリ集約'));
      expect(csv, contains('テストアプリ'));
      expect(csv, contains('1.0.0'));
      expect(csv, contains('テストアプリ2'));
      expect(csv, contains('2.0.0'));
    });

    test('空リストでも例外を投げない', () {
      const service = ExportService();
      final csv = service.buildCsvForAll([]);
      expect(csv, contains('全アプリ集約'));
    });
  });

  group('ExportService.buildAppRosterCsv（登録アプリ一覧のCSVエクスポート）', () {
    test('各アプリの表示名・プラットフォーム・バンドルID/パッケージ名・タグが出力される', () {
      const app1 = ConnectedApp(
        id: 'app1',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.app1',
        displayName: 'テストアプリ',
        sortOrder: 0,
        tags: ['自社', '優先度高'],
      );
      const app2 = ConnectedApp(
        id: 'app2',
        userId: 'u1',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'works.petit.app2',
        displayName: 'テストアプリ2',
        sortOrder: 1,
      );

      const service = ExportService();
      final csv = service.buildAppRosterCsv([app1, app2]);

      expect(csv, contains('登録アプリ一覧'));
      expect(csv, contains('テストアプリ'));
      expect(csv, contains('works.petit.app1'));
      expect(csv, contains('自社'));
      expect(csv, contains('優先度高'));
      expect(csv, contains('テストアプリ2'));
      expect(csv, contains('works.petit.app2'));
    });

    test('タグが無いアプリでも例外を投げない', () {
      const service = ExportService();
      final csv = service.buildAppRosterCsv([app]);
      expect(csv, contains('テストアプリ'));
    });

    test('空リストでも例外を投げない', () {
      const service = ExportService();
      final csv = service.buildAppRosterCsv([]);
      expect(csv, contains('登録アプリ一覧'));
    });
  });

  group('ExportService.sanitizeForFileName', () {
    test('パス区切り文字を含む表示名は安全な文字に置換される', () {
      // app.displayNameはアプリ登録画面の自由入力欄のため、'/'を含む名前が
      // そのままファイル名に使われると存在しないサブディレクトリを指すパスになり、
      // 端末への書き込みが必ず失敗していた（実際のバグ）。
      expect(
        ExportService.sanitizeForFileName('Petit/Works App'),
        isNot(contains('/')),
      );
      expect(
        ExportService.sanitizeForFileName(r'a\b:c*d?e"f<g>h|i'),
        'a_b_c_d_e_f_g_h_i',
      );
    });

    test('前後の空白は除去される', () {
      expect(ExportService.sanitizeForFileName('  My App  '), 'My App');
    });

    test('空白のみの表示名はフォールバック名を返す', () {
      expect(ExportService.sanitizeForFileName('   '), 'app');
    });

    test('通常の日本語アプリ名はそのまま使われる', () {
      expect(ExportService.sanitizeForFileName('リリカン'), 'リリカン');
    });
  });
}
