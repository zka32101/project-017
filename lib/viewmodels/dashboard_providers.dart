import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../models/platform_type.dart';
import '../models/review_status_snapshot.dart';
import '../models/review_status_type.dart';
import '../services/notification_service.dart';
import '../services/service_result.dart';
import '../services/widget_sync_service.dart';
import 'app_review_management_notifier.dart';
import 'connected_apps_notifier.dart';
import 'service_providers.dart';

/// アプリ単体の最新審査状態（ダッシュボードのカード表示用）。
/// 取得成功時、対象アプリの手動ステータス上書きを自動的にクリアする
/// (AppReviewManagementのドキュメントコメント参照。手動上書きは「次回の
/// 実取得成功まで」の一時的な訂正用途のため)。また、前回の実取得成功時から
/// 状態が変化していれば個別のプッシュ通知を発火する
/// (AppReviewManagementNotifier.recordFetchedStatus参照。Should機能)。
final latestReviewStatusProvider =
    FutureProvider.family<ReviewStatusSnapshot?, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  final data = (await service.fetchReviewStatus(app)).unwrap();
  await ref
      .read(appReviewManagementProvider(app.id).notifier)
      .clearManualStatusOverrideAfterFetch();
  final snapshot = data.isEmpty ? null : data.first;
  if (snapshot != null) {
    await ref.read(appReviewManagementProvider(app.id).notifier).recordFetchedStatus(
          app: app,
          status: snapshot.statusType,
          notificationService: ref.read(notificationServiceProvider),
          notificationsEnabled: await _isNotificationsEnabled(ref),
        );
  }
  return snapshot;
});

/// SecureStorageService.readValueはSecureStorageService本体では実際の
/// FlutterSecureStorage(プラットフォームチャネル)を直接叩く実装のため、
/// 通知設定の読み取り失敗が審査状態の取得自体を巻き込んで失敗させない
/// ように吸収する(LocalStoreServiceと同様、通知はベストエフォート機能)。
Future<bool> _isNotificationsEnabled(Ref ref) async {
  try {
    return await ref
            .read(secureStorageServiceProvider)
            .readValue(notificationsEnabledStorageKey) ==
        'true';
  } catch (_) {
    return false;
  }
}

/// ダッシュボード表示順（sortOrder昇順＝リリース間近のアプリを上部固定、Must#5）
final sortedConnectedAppsProvider = Provider<List<ConnectedApp>>((ref) {
  final apps = ref.watch(connectedAppsProvider);
  final sorted = [...apps]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return sorted;
});

/// ダッシュボードの並び替え方式。manual以外を選んだ場合、ドラッグ並び替え
/// (ReorderableListView)は無効化する
/// (ドラッグしても選択中のソート順で毎回上書きされ、操作しても反映されず
/// 混乱するのを避けるため)。
enum DashboardSortOption {
  /// 既存のドラッグ並び替え順(ConnectedApp.sortOrder)
  manual,

  /// 表示名の昇順
  nameAsc,

  /// プラットフォーム別(iOS→Android)、同プラットフォーム内は表示名の昇順
  platform,
}

final dashboardSearchQueryProvider = StateProvider<String>((ref) => '');

/// null = すべてのプラットフォームを表示
final dashboardPlatformFilterProvider =
    StateProvider<PlatformType?>((ref) => null);

/// null = 全てのタグを表示（特定タグで絞り込まない）
final dashboardTagFilterProvider = StateProvider<String?>((ref) => null);

/// true = 要注意（リジェクト/審査中）のアプリだけ表示する
/// （大量アプリ管理用のフィルター機能。isAttentionStatus判定自体は
/// widget_sync_provider.dartのホーム画面ウィジェット集計と同じ基準を使う）。
final dashboardAttentionOnlyProvider = StateProvider<bool>((ref) => false);

final dashboardSortOptionProvider =
    StateProvider<DashboardSortOption>((ref) => DashboardSortOption.manual);

/// 登録アプリ全体で使われているタグの一覧（重複無し、辞書順）。
/// タグフィルターのチップ行を組み立てるために使う。
final allTagsProvider = Provider<List<String>>((ref) {
  final apps = ref.watch(connectedAppsProvider);
  final tags = apps.expand((a) => a.tags).toSet().toList()..sort();
  return tags;
});

/// 手動ステータス上書きがあればそれを、無ければ自動取得値(まだ取得中/
/// 失敗中ならnull)を返す。要注意フィルターの判定・件数集計の両方から
/// 共通で使う(dashboard_screen.dartの_AppStatusCardも同じロジックを持つが、
/// あちらはWidgetRef上のUI表示用で型が異なるため独立している)。
ReviewStatusType? _effectiveStatus(Ref ref, ConnectedApp app) {
  final override =
      ref.watch(appReviewManagementProvider(app.id)).manualStatusOverride;
  final auto = ref.watch(latestReviewStatusProvider(app)).valueOrNull;
  return override ?? auto?.statusType;
}

bool _needsAttention(Ref ref, ConnectedApp app) {
  final status = _effectiveStatus(ref, app);
  return status != null && const WidgetSyncService().isAttentionStatus(status);
}

/// 要注意フィルターのチップに件数バッジを出すための集計。
final dashboardAttentionCountProvider = Provider<int>((ref) {
  final apps = ref.watch(sortedConnectedAppsProvider);
  return apps.where((app) => _needsAttention(ref, app)).length;
});

/// 検索・プラットフォームフィルター・タグフィルター・要注意フィルター・
/// ソートを適用した最終的な表示リスト。元の並び順(sortedConnectedAppsProvider)
/// は保ったまま絞り込み、manual以外のソート方式が選ばれている場合のみ
/// 並び替えを上書きする。
final filteredSortedConnectedAppsProvider = Provider<List<ConnectedApp>>((ref) {
  final apps = ref.watch(sortedConnectedAppsProvider);
  final query = ref.watch(dashboardSearchQueryProvider).trim().toLowerCase();
  final platformFilter = ref.watch(dashboardPlatformFilterProvider);
  final rawTagFilter = ref.watch(dashboardTagFilterProvider);
  final allTags = ref.watch(allTagsProvider);
  // フィルター条件の保存機能で復元したタグが、その後全アプリから削除されて
  // 存在しなくなっているケースを「絞り込み無し」として扱う。そうしないと
  // 全件除外(0件)のまま抜け出せなくなる(タグチップ自体もallTagsProvider
  // ベースで描画されるため、消えたタグのチップは元々表示されない)。
  final tagFilter =
      (rawTagFilter != null && allTags.contains(rawTagFilter)) ? rawTagFilter : null;
  final attentionOnly = ref.watch(dashboardAttentionOnlyProvider);
  final sortOption = ref.watch(dashboardSortOptionProvider);

  final filtered = apps.where((app) {
    if (platformFilter != null && app.platform != platformFilter) {
      return false;
    }
    if (query.isNotEmpty && !app.displayName.toLowerCase().contains(query)) {
      return false;
    }
    if (tagFilter != null && !app.tags.contains(tagFilter)) {
      return false;
    }
    // attentionOnlyがfalseの場合はここから先のref.watchが実行されないため、
    // 全アプリの審査状態を毎回watchする追加コストは発生しない
    // (Riverpodの依存関係はbuild呼び出しごとに動的に記録されるため)。
    if (attentionOnly && !_needsAttention(ref, app)) {
      return false;
    }
    return true;
  }).toList();

  switch (sortOption) {
    case DashboardSortOption.manual:
      break; // apps は既にsortOrder順
    case DashboardSortOption.nameAsc:
      filtered.sort((a, b) => a.displayName.compareTo(b.displayName));
    case DashboardSortOption.platform:
      filtered.sort((a, b) {
        final byPlatform = a.platform.index.compareTo(b.platform.index);
        return byPlatform != 0 ? byPlatform : a.displayName.compareTo(b.displayName);
      });
  }
  return filtered;
});

/// 一括選択モード(ダッシュボードの一括削除機能用)。trueの間、
/// _AppStatusCardはタップで詳細画面へ遷移する代わりに選択トグルになる。
final dashboardSelectionModeProvider = StateProvider<bool>((ref) => false);

/// 一括選択モード中に選択されているアプリID。選択モードを抜けたら
/// DashboardScreen側で明示的にクリアする(次回入った時に前回の選択が
/// 残っていると混乱するため)。
final dashboardSelectedAppIdsProvider = StateProvider<Set<String>>((ref) => {});

/// フィルター/ソート設定の永続化用キー(SecureStorageService経由、
/// notificationsEnabledStorageKeyと同じ「小さな値をJSON化して1キーに
/// まとめて保存する」パターン)。検索キーワードは毎回リセットして良い
/// 一時的な入力のため対象外(TextField自体が状態を持たないため復元も不要)。
const dashboardFilterPrefsStorageKey = 'dashboard_filter_prefs';

/// アプリ再起動後も前回の絞り込み条件を復元する(大量アプリ管理機能の続き)。
/// checklistBootstrapProvider等と同じパターンでDashboardScreen側からbareに
/// watchする。復元に失敗しても(未保存・JSON壊れ等)デフォルト値のまま
/// 画面表示は継続する。
final dashboardFilterPrefsBootstrapProvider = FutureProvider<void>((ref) async {
  final String? raw;
  try {
    raw = await ref
        .read(secureStorageServiceProvider)
        .readValue(dashboardFilterPrefsStorageKey);
  } catch (_) {
    return;
  }
  if (raw == null) return;

  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final platformName = json['platformFilter'] as String?;
    ref.read(dashboardPlatformFilterProvider.notifier).state = platformName == null
        ? null
        : PlatformType.values.firstWhere(
            (p) => p.name == platformName,
            orElse: () => PlatformType.ios,
          );
    ref.read(dashboardTagFilterProvider.notifier).state =
        json['tagFilter'] as String?;
    ref.read(dashboardAttentionOnlyProvider.notifier).state =
        json['attentionOnly'] as bool? ?? false;
    final sortName = json['sortOption'] as String?;
    ref.read(dashboardSortOptionProvider.notifier).state =
        DashboardSortOption.values.firstWhere(
      (s) => s.name == sortName,
      orElse: () => DashboardSortOption.manual,
    );
  } catch (_) {
    // 保存データの形式が壊れていてもデフォルト値のまま画面表示は継続する。
  }
});

/// プラットフォーム/タグ/要注意/ソートのいずれかを変更した直後に呼び出し、
/// 次回起動時も同じ絞り込み条件を復元できるようにする
/// (dashboard_screen.dartの各ChoiceChip/PopupMenuButtonのonSelectedから呼ぶ)。
Future<void> saveDashboardFilterPrefs(WidgetRef ref) async {
  final json = {
    'platformFilter': ref.read(dashboardPlatformFilterProvider)?.name,
    'tagFilter': ref.read(dashboardTagFilterProvider),
    'attentionOnly': ref.read(dashboardAttentionOnlyProvider),
    'sortOption': ref.read(dashboardSortOptionProvider).name,
  };
  try {
    await ref.read(secureStorageServiceProvider).writeValue(
          key: dashboardFilterPrefsStorageKey,
          value: jsonEncode(json),
        );
  } catch (_) {
    // ベストエフォート。保存に失敗してもフィルター機能自体は動作を継続する。
  }
}
