/// 通知イベント種別（審査通過/リジェクト/TestFlightフィードバック/ビルド処理完了 等）
enum NotificationEventType {
  reviewApproved,
  reviewRejected,
  testFlightFeedback,
  buildProcessingComplete,
  buildFailed,
  crashSpike,
}

/// NotificationLog { id, userId, connectedAppId, eventType, payload, receivedAt, readAt }
class NotificationLog {
  final String id;
  final String userId;
  final String connectedAppId;
  final NotificationEventType eventType;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;
  final DateTime? readAt;

  const NotificationLog({
    required this.id,
    required this.userId,
    required this.connectedAppId,
    required this.eventType,
    required this.payload,
    required this.receivedAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  NotificationLog markRead(DateTime at) => NotificationLog(
        id: id,
        userId: userId,
        connectedAppId: connectedAppId,
        eventType: eventType,
        payload: payload,
        receivedAt: receivedAt,
        readAt: at,
      );

  factory NotificationLog.fromJson(Map<String, dynamic> json) =>
      NotificationLog(
        id: json['id'] as String,
        userId: json['userId'] as String,
        connectedAppId: json['connectedAppId'] as String,
        eventType: NotificationEventType.values
            .firstWhere((e) => e.name == json['eventType']),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'connectedAppId': connectedAppId,
        'eventType': eventType.name,
        'payload': payload,
        'receivedAt': receivedAt.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
      };
}
