import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: RirikanApp()));
}

class RirikanApp extends StatelessWidget {
  const RirikanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'リリカン',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // 英語ローンチ前提（設計書 条件2）: 日本語＋英語を初期スコープに含める予定だが、
      // 文字列自体のARB化（intl_ja.arb/intl_en.arb）は次フェーズで未着手のため、
      // アプリ内文字列は現状すべて日本語ハードコード。'en' を supportedLocales に含めると
      // 英語ロケール端末で「サポート対象」と偽りつつ実際は日本語のまま表示されてしまうため、
      // ARB対応が完了するまでは 'ja' のみを宣言する。
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
      ],
      routerConfig: buildAppRouter(),
    );
  }
}
