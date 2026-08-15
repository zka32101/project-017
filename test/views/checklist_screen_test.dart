import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/platform_type.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/viewmodels/checklist_notifier.dart';
import 'package:ririkan/viewmodels/connected_apps_notifier.dart';
import 'package:ririkan/viewmodels/service_providers.dart';
import 'package:ririkan/viewmodels/widget_sync_provider.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        localStoreServiceProvider.overrideWithValue(FakeLocalStoreService()),
        widgetSyncServiceProvider.overrideWithValue(const FakeWidgetSyncService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  testWidgets('項目を「合格」にすると進捗表示・stateの両方に反映される', (tester) async {
    final app = await container.read(connectedAppsProvider.notifier).registerApp(
          userId: 'u1',
          platform: PlatformType.ios,
          bundleIdOrPackageName: 'works.petit.app1',
          displayName: 'テストアプリ',
          apiKey: 'k',
        );

    final router = buildAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/checklist/${app.id}');
    await tester.pumpAndSettle();

    final total = ChecklistItemKey.values.length;
    expect(find.text('0 / $total 項目クリア'), findsOneWidget);

    // 最初の項目の「合格」セグメントをタップする。
    await tester.tap(find.text('合格').first);
    await tester.pumpAndSettle();

    expect(find.text('1 / $total 項目クリア'), findsOneWidget);
    final items = container.read(checklistProvider(app.id));
    expect(
      items.where((i) => i.result == ChecklistResult.pass),
      hasLength(1),
    );
  });
}
