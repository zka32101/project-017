import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/router/app_router.dart';

void main() {
  testWidgets('「通知を許可する」を選んでもアプリ登録画面へ遷移する', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    router.go('/notification-prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();

    expect(find.text('アプリ登録'), findsOneWidget);
  });

  testWidgets('「あとで」を選んでもアプリ登録画面へ遷移する', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    router.go('/notification-prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();

    expect(find.text('アプリ登録'), findsOneWidget);
  });
}
