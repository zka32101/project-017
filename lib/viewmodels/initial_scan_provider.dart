import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connected_apps_notifier.dart';
import 'dashboard_providers.dart';

/// Aha Moment直前の「初回スキャン」処理。登録済み全アプリの最新審査状態を先読みし、
/// ダッシュボード初回表示を待たせない（設計書 Step2 画面フロー: 起動→アプリ登録→初回スキャン）。
final initialScanProvider = FutureProvider<void>((ref) async {
  final apps = ref.watch(connectedAppsProvider);
  await Future.wait(
    apps.map((app) => ref.read(latestReviewStatusProvider(app).future)),
  );
});
