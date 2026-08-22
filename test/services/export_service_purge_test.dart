import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ririkan/services/export_service.dart';

/// ExportServiceは`getApplicationDocumentsDirectory()`(path_provider)経由で
/// 端末のドキュメントディレクトリを参照するため、purgeExpiredExports()の
/// 実際の削除挙動を検証するにはPathProviderPlatform.instanceを実ディレクトリ
/// (dart:ioのDirectory.systemTemp)を指すフェイクへ差し替える。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ririkan_purge_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExportService.purgeExpiredExports', () {
    test('expiryDuration(24時間)以上経過した ririkan_export_*/ririkan_apps_* だけ削除し、'
        '新しいファイル・無関係なファイルは残す', () async {
      final oldExport = File('${tempDir.path}/ririkan_export_old_12345678.csv')
        ..writeAsStringSync('old');
      final oldRoster = File('${tempDir.path}/ririkan_apps_1700000000000.csv')
        ..writeAsStringSync('old');
      final freshExport = File(
        '${tempDir.path}/ririkan_export_fresh_87654321.csv',
      )..writeAsStringSync('fresh');
      final unrelated = File('${tempDir.path}/not_ririkan.txt')
        ..writeAsStringSync('keep');

      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await oldExport.setLastModified(oldTime);
      await oldRoster.setLastModified(oldTime);

      const service = ExportService();
      await service.purgeExpiredExports();

      expect(await oldExport.exists(), isFalse);
      expect(await oldRoster.exists(), isFalse);
      expect(await freshExport.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
    });

    test('ドキュメントディレクトリ自体が存在しなくても例外を投げない', () async {
      final missingDir = Directory('${tempDir.path}/does-not-exist');
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        missingDir.path,
      );

      const service = ExportService();
      await expectLater(service.purgeExpiredExports(), completes);
    });

    test('24時間未満のファイルは削除されない', () async {
      final recentExport = File(
        '${tempDir.path}/ririkan_export_recent_00000001.csv',
      )..writeAsStringSync('recent');
      await recentExport.setLastModified(
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      const service = ExportService();
      await service.purgeExpiredExports();

      expect(await recentExport.exists(), isTrue);
    });
  });
}
