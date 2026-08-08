/// Webhook提供元（Apple / Google）
enum WebhookProvider { apple, google }

/// WebhookEndpoint { id, connectedAppId, provider, endpointSecret, isActive }
///
/// endpointSecret はクライアントには本来渡らない想定（Cloud Functions側管理）。
/// クライアントモデルとしては「登録済みか」の表示用に isActive のみ利用する。
class WebhookEndpoint {
  final String id;
  final String connectedAppId;
  final WebhookProvider provider;
  final String? endpointSecret;
  final bool isActive;

  const WebhookEndpoint({
    required this.id,
    required this.connectedAppId,
    required this.provider,
    this.endpointSecret,
    required this.isActive,
  });

  factory WebhookEndpoint.fromJson(Map<String, dynamic> json) =>
      WebhookEndpoint(
        id: json['id'] as String,
        connectedAppId: json['connectedAppId'] as String,
        provider: WebhookProvider.values
            .firstWhere((e) => e.name == json['provider']),
        endpointSecret: json['endpointSecret'] as String?,
        isActive: json['isActive'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectedAppId': connectedAppId,
        'provider': provider.name,
        'endpointSecret': endpointSecret,
        'isActive': isActive,
      };
}
