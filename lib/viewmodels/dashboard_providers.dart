import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connected_app.dart';
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
    case ServiceFailure<List<ReviewStatusSnapshot>>():
      return null;
  }
});

/// ダッシュボード表示順（sortOrder昇順＝リリース間近のアプリを上部固定、Must#5）
final sortedConnectedAppsProvider = Provider<List<ConnectedApp>>((ref) {
  final apps = ref.watch(connectedAppsProvider);
  final sorted = [...apps]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return sorted;
});
