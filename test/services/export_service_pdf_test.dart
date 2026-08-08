import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/review_status_type.dart';
import 'package:ririkan/services/export_service.dart';

void main() {
  // rootBundle経由のアセット読み込みは flutter_test のバインディング初期化が必要。
  TestWidgetsFlutterBinding.ensureInitialized();

  const app = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    displayName: '日本語テストアプリ',
    sortOrder: 0,
  );

  group('ExportService.buildPdf（日本語フォント埋め込み）', () {
    test('Noto Sans JPアセットを読み込みPDFの妥当なバイト列を生成できる', () async {
      const service = ExportService();
      final history = [
        ReviewStatusSnapshot(
          id: 's1',
          connectedAppId: app.id,
          versionString: '1.0.0',
          statusType: ReviewStatusType.rejected,
          fetchedAt: DateTime(2026, 8, 5),
        ),
      ];

      final bytes = await service.buildPdf(app, history, const [], const []);

      // PDFファイルのマジックバイト "%PDF" で先頭を確認し、フォント埋め込みを含む
      // ドキュメント全体が例外なく生成されたことを検証する（目視ではなくバイト列で判定）。
      expect(bytes.length, greaterThan(1000));
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });

    test('データが空でも例外を投げず有効なPDFを生成する', () async {
      const service = ExportService();
      final bytes = await service.buildPdf(app, const [], const [], const []);
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });
  });
}
