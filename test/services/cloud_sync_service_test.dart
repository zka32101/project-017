import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/services/cloud_sync_service.dart';
import 'package:ririkan/services/local_store_service.dart';

void main() {
  // Firebaseの実プロジェクト設定値は現状プレースホルダ値のままのため、
  // initialize()はFirebase.initializeApp()を呼ばず未設定のまま終わる
  // (実プラットフォームチャネルに一切触れないため、この範囲はflutter test
  // 環境でも安全に検証できる)。実際の鍵が設定された場合の挙動
  // (Firebase.*/FirebaseAuth.*/FirebaseFirestore.*呼び出し)はSDK側の
  // 責務であり、ここではテストしない。
  group('FirebaseCloudSyncService（プレースホルダ設定のまま）', () {
    test('initialize()は例外を投げず、未設定状態のままになる', () async {
      final service = FirebaseCloudSyncService();
      await expectLater(service.initialize(), completes);
    });

    test('未設定のままbackup()は例外を投げない（プラットフォームチャネル未使用）',
        () async {
      final service = FirebaseCloudSyncService();
      await service.initialize();
      const app = ConnectedApp(
        id: 'app1',
        userId: 'u1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.app1',
        apiKeyRef: 'app1',
        displayName: 'App One',
        sortOrder: 0,
      );
      await expectLater(
        service.backup(const LocalState(apps: [app], plan: UserPlan.free)),
        completes,
      );
    });

    test('未設定のままrestore()はnullを返す（プラットフォームチャネル未使用）',
        () async {
      final service = FirebaseCloudSyncService();
      await service.initialize();
      expect(await service.restore(), isNull);
    });
  });
}
