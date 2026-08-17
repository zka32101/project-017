import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
import '../models/platform_type.dart';
import '../models/review_status_snapshot.dart';
import '../services/service_result.dart';
import 'connected_apps_notifier.dart';
import 'service_providers.dart';

/// アプリ単体の最新審査状態（ダッシュボードのカード表示用）。
final latestReviewStatusProvider =
    FutureProvider.family<ReviewStatusSnapshot?, ConnectedApp>(
        (ref, app) async {
  final service = ref.watch(reviewStatusServiceProvider(app.platform));
  final result = await service.fetchReviewStatus(app);
  switch (result) {
    case ServiceSuccess<List<ReviewStatusSnapshot>>(:final data):
      return data.isEmpty ? null : data.first;
    case ServiceFailure<List<ReviewStatusSnapshot>> failure:
      throw ServiceFailureException(failure);
  }
});

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

final dashboardSortOptionProvider =
    StateProvider<DashboardSortOption>((ref) => DashboardSortOption.manual);

/// 検索・プラットフォームフィルター・ソートを適用した最終的な表示リスト。
/// 元の並び順(sortedConnectedAppsProvider)は保ったまま絞り込み、
/// manual以外のソート方式が選ばれている場合のみ並び替えを上書きする。
final filteredSortedConnectedAppsProvider = Provider<List<ConnectedApp>>((ref) {
  final apps = ref.watch(sortedConnectedAppsProvider);
  final query = ref.watch(dashboardSearchQueryProvider).trim().toLowerCase();
  final platformFilter = ref.watch(dashboardPlatformFilterProvider);
  final sortOption = ref.watch(dashboardSortOptionProvider);

  final filtered = apps.where((app) {
    if (platformFilter != null && app.platform != platformFilter) {
      return false;
    }
    if (query.isNotEmpty && !app.displayName.toLowerCase().contains(query)) {
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
