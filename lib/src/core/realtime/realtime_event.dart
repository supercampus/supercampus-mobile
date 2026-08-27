import 'dart:convert';

class RealtimeEvent {
  const RealtimeEvent({
    required this.id,
    required this.type,
    required this.version,
    required this.occurredAt,
    required this.data,
  });

  final String id;
  final String type;
  final int version;
  final DateTime occurredAt;
  final Map<String, dynamic> data;

  static RealtimeEvent? tryParse(Object? message) {
    try {
      final decoded = message is String ? jsonDecode(message) : message;
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final id = json['id']?.toString().trim() ?? '';
      final type = json['type']?.toString().trim() ?? '';
      final occurredAt = DateTime.tryParse(
        json['occurred_at']?.toString() ?? '',
      );
      if (id.isEmpty || type.isEmpty || occurredAt == null) return null;

      final rawData = json['data'];
      return RealtimeEvent(
        id: id,
        type: type,
        version: (json['version'] as num?)?.toInt() ?? 1,
        occurredAt: occurredAt,
        data: rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : const <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }
}
