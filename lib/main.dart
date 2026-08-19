import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/gen/app_localizations.dart';
import 'router/app_router.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';

/// 通知・広告・課金SDKはいずれも副次的な機能であり、初期化失敗がアプリの
/// 起動そのもの(runApp)をブロックしてはならない。個別にcatchし、失敗しても
/// 残りの初期化とアプリ起動は続行する(該当機能が単に動かないだけになる)。
Future<void> _initializeSilently(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (e, st) {
    debugPrint('$name の初期化に失敗しました(この機能のみ無効化されます): $e\n$st');
  }
}

void main() async {
  // 各種プラグインの初期化はmain()で1回だけ行う(Widget buildからは呼ばない。
  // flutter test環境では対応するproviderを必ずフェイクへoverrideするため、
  // この初期化コード自体がテストで実行されることはない)。
  WidgetsFlutterBinding.ensureInitialized();
  // 3つとも互いに依存が無く、それぞれ_initializeSilently内で自身の失敗を
  // 握りつぶすため、直列にawaitして起動を待たせる理由が無い。並行実行して
  // 起動時間を「合計」ではなく「最も遅い1つ」に短縮する。
  await Future.wait([
    _initializeSilently('通知', () => LocalNotificationService().initialize()),
    _initializeSilently('広告SDK', () => const AdService().initialize()),
    _initializeSilently(
        '課金SDK', () => RevenueCatPurchaseService().initialize()),
  ]);
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
