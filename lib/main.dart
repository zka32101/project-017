import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/gen/app_localizations.dart';
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
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // 英語ローンチ前提（設計書 条件2）: 日本語＋英語対応。
      // 文字列はlib/l10n/*.arbで管理し、flutter gen-l10nでAppLocalizationsを生成する。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(),
    );
  }
}
