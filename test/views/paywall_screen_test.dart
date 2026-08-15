import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/user_plan.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

void main() {
  late ProviderContainer container;
  late FakeLocalStoreService localStore;

  setUp(() {
    localStore = FakeLocalStoreService();
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(localStore),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  testWidgets('「Proにアップグレード」でプランが更新され、永続化もされる（setPlan経由）',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.push('/paywall');
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.free);

    await tester.tap(find.text('Pro にアップグレード'));
    await tester.pumpAndSettle();

    expect(container.read(userPlanProvider), UserPlan.pro);
    // paywall_screen.dart は userPlanProvider.notifier.state を直接書き換えず
    // ConnectedAppsNotifier.setPlan() 経由にすることで永続化される
    // （直接書き換えると再起動時に消える、PR #4のリグレッション防止）。
    final saved = await localStore.load();
    expect(saved?.plan, UserPlan.pro);

    // pop後にapp-registrationへpushされる。
    expect(find.text('アプリ登録'), findsOneWidget);
  });
}
