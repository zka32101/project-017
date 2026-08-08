import 'platform_type.dart';

/// BuildFailureLog { id, connectedAppId, buildNumber, platform,
///   failureReason, processingErrorDetail, occurredAt }
class BuildFailureLog {
  final String id;
  final String connectedAppId;
  final String buildNumber;
  final PlatformType platform;
  final String failureReason;
  final String? processingErrorDetail;
  final DateTime occurredAt;

  const BuildFailureLog({
    required this.id,
    required this.connectedAppId,
    required this.buildNumber,
    required this.platform,
    required this.failureReason,
    this.processingErrorDetail,
    required this.occurredAt,
  });

  factory BuildFailureLog.fromJson(Map<String, dynamic> json) =>
      BuildFailureLog(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        buildNumber: json['buildNumber'] as String,
        platform:
            PlatformType.values.firstWhere((e) => e.name == json['platform']),
        failureReason: json['failureReason'] as String,
        processingErrorDetail: json['processingErrorDetail'] as String?,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'buildNumber': buildNumber,
        'platform': platform.name,
        'failureReason': failureReason,
        'processingErrorDetail': processingErrorDetail,
        'occurredAt': occurredAt.toIso8601String(),
      };
}
