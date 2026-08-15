import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/router/app_router.dart';

import '../test_utils/test_app.dart';

void main() {
  testWidgets('「次へ」を最後まで進めると「はじめる」に変わり、通知プロンプトへ遷移する',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: wrapWithLocalizedRouter(router),
      ),
    );
    router.go('/onboarding');
    await tester.pumpAndSettle();

    expect(find.text('複数アプリの状態を、1つの管制塔で'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('登録後は完全自動'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('APIキーは端末内だけで保管'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('審査通過・リジェクトを見逃さないために'), findsOneWidget);
  });
}
