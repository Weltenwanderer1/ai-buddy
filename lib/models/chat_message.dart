import 'dart:convert';
import 'package:uuid/uuid.dart';

enum MessageType { text, system, error, voice, toolActivity, navigation }

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final Map<String, dynamic>? metadata; // Extra data e.g. route, target coords

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        if (metadata != null) 'metadata': jsonEncode(metadata),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? const Uuid().v4(),
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        type: MessageType.values.firstWhere(
          (t) => t.name == (json['type'] as String?),
          orElse: () => MessageType.text,
        ),
        metadata: json['metadata'] != null
            ? (() {
                try {
                  return jsonDecode(json['metadata'] as String) as Map<String, dynamic>;
                } catch (_) {
                  return null;
                }
              })()
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChatMessage && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
