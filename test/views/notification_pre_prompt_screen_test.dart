import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/router/app_router.dart';
import 'package:ririkan/services/notification_service.dart';
import 'package:ririkan/viewmodels/service_providers.dart';

import '../test_utils/fakes.dart';
import '../test_utils/test_app.dart';

void main() {
  testWidgets('「通知を許可する」を選ぶと許可リクエスト・スケジュールが行われ、'
      'アプリ登録画面へ遷移する', (tester) async {
    final notificationService = FakeNotificationService(permissionGranted: true);
    final secureStorage = FakeSecureStorageService();
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
        ],
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/notification-prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();

    expect(find.text('アプリ登録'), findsOneWidget);
    expect(notificationService.requestPermissionCalled, isTrue);
    expect(notificationService.scheduleCalled, isTrue);
    expect(
      await secureStorage.readValue(notificationsEnabledStorageKey),
      'true',
    );
  });

  testWidgets('通知許可が拒否されてもスケジュールせずアプリ登録画面へ遷移する', (tester) async {
    final notificationService = FakeNotificationService(permissionGranted: false);
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/notification-prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();

    expect(find.text('アプリ登録'), findsOneWidget);
    expect(notificationService.requestPermissionCalled, isTrue);
    expect(notificationService.scheduleCalled, isFalse);
  });

  testWidgets('「あとで」を選ぶと許可リクエストを行わずアプリ登録画面へ遷移する', (tester) async {
    final notificationService = FakeNotificationService();
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          secureStorageServiceProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/notification-prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();

    expect(find.text('アプリ登録'), findsOneWidget);
    expect(notificationService.requestPermissionCalled, isFalse);
  });
}
