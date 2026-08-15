import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ririkan/l10n/gen/app_localizations.dart';

/// テスト用にGoRouterをMaterialApp.routerへ包む。実際のRirikanApp（main.dart）と
/// 同じlocalizationsDelegates/supportedLocalesを設定した上で、locale はテストの
/// 決定性のため常に 'ja' に固定する（テスト実行環境のシステムロケールに依存させない）。
/// これが無いと、supportedLocalesにenも含まれるようになったことで、テスト環境の
/// ロケール解決によっては英語文言に解決され、日本語文字列を探すfind.text(...)が
/// 軒並み失敗する。
Widget wrapWithLocalizedRouter(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}
