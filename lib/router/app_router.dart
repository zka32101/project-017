import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/connected_app.dart';
import '../viewmodels/connected_apps_notifier.dart';
import '../views/app_detail/app_detail_screen.dart';
import '../views/app_registration/app_registration_screen.dart';
import '../views/checklist/checklist_screen.dart';
import '../views/export/export_screen.dart';
import '../views/dashboard/dashboard_screen.dart';
import '../views/onboarding/notification_pre_prompt_screen.dart';
import '../views/onboarding/onboarding_screen.dart';
import '../views/paywall/paywall_screen.dart';
import '../views/scan/initial_scan_screen.dart';
import '../views/settings/settings_screen.dart';

/// 画面フロー（設計書 Step2）:
/// 起動 → オンボーディング → 通知プレプロンプト → アプリ登録 → 初回スキャン → ダッシュボード
/// ダッシュボード → アプリ詳細
///
/// /app-detail/:id 等は extra(ConnectedApp)無しでもidだけから解決できる
/// ため、URLベースのディープリンク一般に対応できる構造になっている。
/// 審査状態の個別通知(NotificationService.showReviewStatusChangedNotification)
/// はこの仕組みを使って「通知タップ→該当アプリの詳細画面（リジェクト時は
/// リジェクト理由タブ）を開く」を実現する(main.dartでGoRouterの
/// push/goを通知タップ・起動時ペイロードへ結線している)。
GoRouter buildAppRouter() {
  return GoRouter(
    // ドッグフーディング・実機テスト用：初期位置をダッシュボードに変更
    // 通常フロー（/onboarding）は UI テストやデモ用途で必要に応じて手動遷移可能
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/notification-prompt',
        builder: (context, state) => const NotificationPrePromptScreen(),
      ),
      GoRoute(
        path: '/app-registration',
        builder: (context, state) => const AppRegistrationScreen(),
      ),
      GoRoute(
        path: '/initial-scan',
        builder: (context, state) => const InitialScanScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/app-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          // ?tab=<index> はリジェクト通知タップ時にリジェクト理由タブを
          // 直接開くために使う(NotificationService.showReviewStatusChangedNotification
          // 参照)。それ以外の遷移元では付与されず、その場合は既定の0番目
          // (審査履歴タブ)が開く。
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          if (extra is ConnectedApp) {
            return AppDetailScreen(app: extra, initialTabIndex: tab);
          }
          // ディープリンク（通知タップ等）で extra が無い場合は id から解決する。
          return _ByIdResolver(
            id: id,
            builder: (app) => AppDetailScreen(app: app, initialTabIndex: tab),
          );
        },
      ),
      GoRoute(
        path: '/checklist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          if (extra is ConnectedApp) {
            return ChecklistScreen(app: extra);
          }
          return _ByIdResolver(id: id, builder: (app) => ChecklistScreen(app: app));
        },
      ),
      GoRoute(
        path: '/export/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          if (extra is ConnectedApp) {
            return ExportScreen(app: extra);
          }
          return _ByIdResolver(id: id, builder: (app) => ExportScreen(app: app));
        },
      ),
      GoRoute(
        path: '/export-all',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
}

/// connectedAppsProvider から id 一致するアプリを探す共通ヘルパー
/// （extra なしディープリンク、通知タップ等のフォールバック解決用）。
ConnectedApp? _resolveConnectedApp(WidgetRef ref, String id) {
  final apps = ref.watch(connectedAppsProvider);
  final matches = apps.where((a) => a.id == id);
  return matches.isEmpty ? null : matches.first;
}

/// extra なしディープリンクでidに対応するアプリが見つからなかった場合の共通表示。
class _AppNotFoundScaffold extends StatelessWidget {
  const _AppNotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).commonAppNotFound)),
    );
  }
}

/// extra なしディープリンク（通知タップ等）で id から ConnectedApp を解決し、
/// 見つかった場合は builder で目的の画面を組み立てる共通リゾルバ。
/// AppDetail/Checklist/Export の3ルートとも「id解決→見つからなければ
/// _AppNotFoundScaffold、見つかれば対応する画面」という同じ処理だったため、
/// 画面の組み立てだけを builder として差し替え可能にした。
class _ByIdResolver extends ConsumerWidget {
  final String id;
  final Widget Function(ConnectedApp app) builder;
  const _ByIdResolver({required this.id, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = _resolveConnectedApp(ref, id);
    if (app == null) {
      return const _AppNotFoundScaffold();
    }
    return builder(app);
  }
}
