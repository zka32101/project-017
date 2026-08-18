import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/revenue_summary.dart';

/// RevenueCat REST API (v2, Charts & Metrics)への通信失敗を表す例外。
class RevenueCatApiException implements Exception {
  final String message;
  const RevenueCatApiException(this.message);

  @override
  String toString() => 'RevenueCatApiException($message)';
}

/// RevenueCat Charts & Metrics API (v2) 実接続クライアント。
///
/// 【重要な注意】api.revenuecat.com はこの開発環境のネットワークegress
/// ポリシーでブロックされており、実際のレスポンス形式を直接検証できて
/// いない。以下の実装は検索結果から得られた二次情報を基にした最善推定であり、
/// 実際のRevenueCat OAuthアプリ・実データでの動作確認が別途必要:
/// - GET /v2/projects: 認可済みプロジェクト一覧。先頭の1件を使う
///   (複数プロジェクトを跨ぐOAuthアプリの場合は正しく選べない可能性がある)。
/// - GET /v2/projects/{id}/charts/{chart_name}: 時系列データ。
///   chart_name=revenue、resolution=day、start_date/end_date(YYYY-MM-DD)を
///   クエリパラメータとして渡す想定。レスポンス内の各データポイントに
///   日付フィールドが含まれているかどうかも未確認のため、含まれていれば
///   それを使い、無ければ start_date からの経過日数で日付を復元する。
/// - RevenueCatは「ダウンロード数」を計測する製品ではない(サブスクリプション/
///   購入イベントが対象)ため、DiscoverableAppのdownloadCountに相当する
///   指標が無い。そのためRevenueSummary.downloadCountは常に0を返す
///   (実装可能になり次第、対応するチャート(new_customers等)への
///   差し替えを検討する)。
class RevenueCatApiClient {
  RevenueCatApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _baseUrl = 'https://api.revenuecat.com/v2';

  Future<String> fetchProjectId(String accessToken) async {
    final body = await _getJson(Uri.parse('$_baseUrl/projects'), accessToken);
    final projects = (body['projects'] as List<dynamic>?) ?? const [];
    if (projects.isEmpty) {
      throw const RevenueCatApiException('アクセス可能なRevenueCatプロジェクトが見つかりません');
    }
    final first = projects.first as Map<String, dynamic>;
    final id = first['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const RevenueCatApiException('プロジェクト応答の形式が不正です');
    }
    return id;
  }

  Future<List<RevenueSummary>> fetchRevenueSeries({
    required String accessToken,
    required String projectId,
    required String connectedAppId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);
    final uri = Uri.parse(
      '$_baseUrl/projects/$projectId/charts/revenue',
    ).replace(queryParameters: {
      'resolution': 'day',
      'start_date': startStr,
      'end_date': endStr,
    });

    final body = await _getJson(uri, accessToken);
    final points = _extractPoints(body);

    return List.generate(points.length, (i) {
      final point = points[i];
      final dateStr = point['date'] as String?;
      final date = dateStr != null
          ? (DateTime.tryParse(dateStr) ?? startDate.add(Duration(days: i)))
          : startDate.add(Duration(days: i));
      final value = point['value'];
      final revenue = value is num ? value.toDouble() : 0.0;

      return RevenueSummary(
        id: '${connectedAppId}_rev_${_formatDate(date)}',
        connectedAppId: connectedAppId,
        date: date,
        revenue: revenue,
        // RevenueCatはダウンロード数を計測しないため常に0(クラスdocコメント参照)。
        downloadCount: 0,
      );
    });
  }

  /// レスポンス形式が未確認のため、複数のありそうな形をゆるく試す:
  /// { "series": [ { "data": [ {..}, ... ] } ] } または { "data": [ {..}, ... ] }。
  List<Map<String, dynamic>> _extractPoints(Map<String, dynamic> body) {
    final series = body['series'] as List<dynamic>?;
    if (series != null && series.isNotEmpty) {
      final firstSeries = series.first;
      if (firstSeries is Map<String, dynamic>) {
        final data = firstSeries['data'] as List<dynamic>?;
        if (data != null) {
          return data.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    final data = body['data'] as List<dynamic>?;
    if (data != null) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String accessToken) async {
    final http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw RevenueCatApiException('RevenueCat APIへの接続に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw RevenueCatApiException(
        'RevenueCat APIの呼び出しに失敗しました(HTTP ${response.statusCode})。'
        'アクセストークンの有効期限、またはスコープ(charts_metrics:*)を確認してください。',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw const RevenueCatApiException('RevenueCat APIのレスポンス形式が不正です');
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
