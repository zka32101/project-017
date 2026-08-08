import 'review_status_type.dart';

/// ReviewStatusSnapshot { id, connectedAppId, versionString, statusType, fetchedAt }
class ReviewStatusSnapshot {
  final String id;
  final String connectedAppId;
  final String versionString;
  final ReviewStatusType statusType;
  final DateTime fetchedAt;

  const ReviewStatusSnapshot({
    required this.id,
    required this.connectedAppId,
    required this.versionString,
    required this.statusType,
    required this.fetchedAt,
  });

  factory ReviewStatusSnapshot.fromJson(Map<String, dynamic> json) =>
      ReviewStatusSnapshot(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        versionString: json['versionString'] as String,
        statusType: ReviewStatusType.fromKey(json['statusType'] as String),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'versionString': versionString,
        'statusType': statusType.name,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
