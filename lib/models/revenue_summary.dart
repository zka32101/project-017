/// RevenueSummary { connectedAppId, date, revenue, downloadCount, currencyCode }
/// 売上・DL数サマリー（Should機能、設計書 Step3・RevenueCat連携）。
class RevenueSummary {
  final String id;
  final String connectedAppId;
  final DateTime date;
  final double revenue;
  final int downloadCount;
  final String currencyCode;

  const RevenueSummary({
    required this.id,
    required this.connectedAppId,
    required this.date,
    required this.revenue,
    required this.downloadCount,
    this.currencyCode = 'JPY',
  });

  factory RevenueSummary.fromJson(Map<String, dynamic> json) => RevenueSummary(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        date: DateTime.parse(json['date'] as String),
        revenue: (json['revenue'] as num).toDouble(),
        downloadCount: json['downloadCount'] as int,
        currencyCode: json['currencyCode'] as String? ?? 'JPY',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'date': date.toIso8601String(),
        'revenue': revenue,
        'downloadCount': downloadCount,
        'currencyCode': currencyCode,
      };
}
