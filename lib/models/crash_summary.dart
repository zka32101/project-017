/// CrashSummary { id, connectedAppId, date, crashFreeRate, crashCount }
class CrashSummary {
  final String id;
  final String connectedAppId;
  final DateTime date;
  final double crashFreeRate;
  final int crashCount;

  const CrashSummary({
    required this.id,
    required this.connectedAppId,
    required this.date,
    required this.crashFreeRate,
    required this.crashCount,
  });

  /// クラッシュ率急上昇アラート判定（Must#3）。閾値はRemote Config想定、初期値99.0%。
  bool isSpiking({double threshold = 99.0}) => crashFreeRate < threshold;

  factory CrashSummary.fromJson(Map<String, dynamic> json) => CrashSummary(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        date: DateTime.parse(json['date'] as String),
        crashFreeRate: (json['crashFreeRate'] as num).toDouble(),
        crashCount: json['crashCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'date': date.toIso8601String(),
        'crashFreeRate': crashFreeRate,
        'crashCount': crashCount,
      };
}
