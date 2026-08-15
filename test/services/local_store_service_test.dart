import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/connected_app.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/services/local_store_service.dart';

void main() {
  const app1 = ConnectedApp(
    id: 'app1',
    userId: 'u1',
    platform: PlatformType.ios,
    bundleIdOrPackageName: 'works.petit.app1',
    apiKeyRef: 'app1',
    displayName: 'App1',
    sortOrder: 0,
  );
  const app2 = ConnectedApp(
    id: 'app2',
    userId: 'u1',
    platform: PlatformType.android,
    bundleIdOrPackageName: 'works.petit.app2',
    apiKeyRef: 'app2',
    displayName: 'App2',
    sortOrder: 1,
  );

  group('LocalState.toJson/fromJson', () {
    test('往復して同値になる', () {
      const state = LocalState(apps: [app1, app2], plan: UserPlan.pro);
      final restored = LocalState.fromJson(state.toJson());

      expect(restored.apps.map((a) => a.id), ['app1', 'app2']);
      expect(restored.apps[0].displayName, 'App1');
      expect(restored.apps[1].platform, PlatformType.android);
      expect(restored.plan, UserPlan.pro);
    });

    test('appsが空でも例外を投げない', () {
      const state = LocalState(apps: [], plan: UserPlan.free);
      final restored = LocalState.fromJson(state.toJson());
      expect(restored.apps, isEmpty);
      expect(restored.plan, UserPlan.free);
    });

    test('plan文字列が未知の値でもfreeにフォールバックする（フォーマット変更等への耐性）', () {
      final restored = LocalState.fromJson({'apps': [], 'plan': 'unknown_plan'});
      expect(restored.plan, UserPlan.free);
    });

    test('plan自体が欠けていてもfreeにフォールバックする', () {
      final restored = LocalState.fromJson({'apps': []});
      expect(restored.plan, UserPlan.free);
    });

    test('1件だけ壊れたapp要素があっても、その要素だけ読み飛ばして他は復元する', () {
      final json = {
        'apps': [
          app1.toJson(),
          {'this is': 'not a valid ConnectedApp'},
          app2.toJson(),
        ],
        'plan': 'free',
      };
      final restored = LocalState.fromJson(json);
      expect(restored.apps.map((a) => a.id), ['app1', 'app2']);
    });

    test('apps自体が想定外の型でも例外を投げず空リストとして扱う', () {
      final restored = LocalState.fromJson({'apps': 'not a list', 'plan': 'free'});
      expect(restored.apps, isEmpty);
    });
  });
}
