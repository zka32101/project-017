import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/gen/app_localizations.dart';
import 'router/app_router.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  // 各種プラグインの初期化はmain()で1回だけ行う(Widget buildからは呼ばない。
  // flutter test環境では対応するproviderを必ずフェイクへoverrideするため、
  // この初期化コード自体がテストで実行されることはない)。
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService().initialize();
  await const AdService().initialize();
  await RevenueCatPurchaseService().initialize();
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
