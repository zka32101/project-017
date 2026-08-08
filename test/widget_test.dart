// リリカン起動スモークテスト
// ドッグフーディング・実機テスト用に initialLocation を /dashboard に変更したため、
// 起動直後はダッシュボード画面が表示される（デモアプリが自動初期化される）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ririkan/main.dart';

void main() {
  testWidgets('起動するとダッシュボードが表示される（デモアプリ自動初期化）',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RirikanApp()));
    await tester.pumpAndSettle();

    // ダッシュボード画面の表示確認（デモアプリが自動初期化される）
    expect(find.text('リリカン'), findsWidgets); // AppBar のタイトル
    expect(find.text('Sample iOS App'), findsOneWidget); // デモアプリ1: iOS
    expect(find.text('Sample Android App'), findsOneWidget); // デモアプリ2: Android
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget); // 設定ボタン
  });
}
