class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.tripId,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? tripId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      tripId: json['tripId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
    );
  }
}

class NotificationPageResult {
  NotificationPageResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<AppNotification> items;
  final int total;
  final int limit;
  final int offset;

  factory NotificationPageResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return NotificationPageResult(
      items: list
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      limit: (json['limit'] as num?)?.toInt() ?? list.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
