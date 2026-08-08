enum ExportFormat { pdf, csv }

enum ExportJobStatus { pending, ready, failed }

/// ExportJob { id, userId, connectedAppId(null=全アプリ), format, dateRange,
///   status, fileUrl, expiresAt }  Should機能
class ExportJob {
  final String id;
  final String userId;
  final String? connectedAppId;
  final ExportFormat format;
  final DateTimeRange dateRange;
  final ExportJobStatus status;
  final String? fileUrl;
  final DateTime? expiresAt;

  const ExportJob({
    required this.id,
    required this.userId,
    this.connectedAppId,
    required this.format,
    required this.dateRange,
    required this.status,
    this.fileUrl,
    this.expiresAt,
  });

  bool get isAllApps => connectedAppId == null;

  factory ExportJob.fromJson(Map<String, dynamic> json) => ExportJob(
        id: json['id'] as String,
        userId: json['userId'] as String,
        connectedAppId: json['connectedAppId'] as String?,
        format: ExportFormat.values.firstWhere((e) => e.name == json['format']),
        dateRange: DateTimeRange(
          start: DateTime.parse(json['dateRange']['start'] as String),
          end: DateTime.parse(json['dateRange']['end'] as String),
        ),
        status:
            ExportJobStatus.values.firstWhere((e) => e.name == json['status']),
        fileUrl: json['fileUrl'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'connectedAppId': connectedAppId,
        'format': format.name,
        'dateRange': {
          'start': dateRange.start.toIso8601String(),
          'end': dateRange.end.toIso8601String(),
        },
        'status': status.name,
        'fileUrl': fileUrl,
        'expiresAt': expiresAt?.toIso8601String(),
      };
}

/// flutter/material.dart の DateTimeRange と衝突しないよう、モデル層は独立定義。
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
