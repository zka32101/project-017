import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';

void main() {
  group('ConnectedApp', () {
    test('toJson/fromJson が往復して同値になる', () {
      const app = ConnectedApp(
        id: 'app1',
        userId: 'user1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.ririkan',
        apiKeyRef: 'app1',
        displayName: 'リリカン',
        sortOrder: 0,
      );
      final restored = ConnectedApp.fromJson(app.toJson());

      expect(restored.id, app.id);
      expect(restored.platform, app.platform);
      expect(restored.bundleIdOrPackageName, app.bundleIdOrPackageName);
      expect(restored.apiKeyRef, app.apiKeyRef);
      expect(restored.hasApiKeyRegistered, isTrue);
    });

    test('apiKeyRef が未設定なら hasApiKeyRegistered は false', () {
      const app = ConnectedApp(
        id: 'app2',
        userId: 'user1',
        platform: PlatformType.android,
        bundleIdOrPackageName: 'works.petit.ririkan',
        displayName: 'リリカン',
        sortOrder: 0,
      );
      expect(app.hasApiKeyRegistered, isFalse);
    });

    test('copyWith は指定フィールドのみ更新する', () {
      const app = ConnectedApp(
        id: 'app1',
        userId: 'user1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.ririkan',
        displayName: 'リリカン',
        sortOrder: 0,
      );
      final moved = app.copyWith(sortOrder: 3);
      expect(moved.sortOrder, 3);
      expect(moved.displayName, app.displayName);
      expect(moved.id, app.id);
    });

    test('id が同じなら他フィールドが違っても等価（Riverpod familyキャッシュ維持のため）', () {
      const app = ConnectedApp(
        id: 'app1',
        userId: 'user1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.ririkan',
        displayName: 'リリカン',
        sortOrder: 0,
      );
      final movedCopy = app.copyWith(sortOrder: 5, displayName: '別名');

      expect(movedCopy, equals(app));
      expect(movedCopy.hashCode, equals(app.hashCode));
    });

    test('id が異なれば非等価', () {
      const app1 = ConnectedApp(
        id: 'app1',
        userId: 'user1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.ririkan',
        displayName: 'リリカン',
        sortOrder: 0,
      );
      const app2 = ConnectedApp(
        id: 'app2',
        userId: 'user1',
        platform: PlatformType.ios,
        bundleIdOrPackageName: 'works.petit.ririkan',
        displayName: 'リリカン',
        sortOrder: 0,
      );

      expect(app1, isNot(equals(app2)));
    });
  });
}
