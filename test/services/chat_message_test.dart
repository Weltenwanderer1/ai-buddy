import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('constructor assigns UUID if not provided', () {
      final msg = ChatMessage(text: 'Hello', isUser: true);
      expect(msg.id, isNotEmpty);
      expect(msg.text, 'Hello');
      expect(msg.isUser, isTrue);
      expect(msg.type, MessageType.text);
      expect(msg.timestamp, isNotNull);
    });

    test('constructor preserves provided id', () {
      final msg = ChatMessage(id: 'custom-id', text: 'Hi', isUser: false);
      expect(msg.id, 'custom-id');
    });

    test('constructor accepts custom type', () {
      final msg = ChatMessage(text: 'Error!', isUser: false, type: MessageType.error);
      expect(msg.type, MessageType.error);
    });

    test('toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'test-123',
        text: 'Hello world',
        isUser: true,
        timestamp: now,
        type: MessageType.voice,
      );

      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, 'test-123');
      expect(restored.text, 'Hello world');
      expect(restored.isUser, isTrue);
      expect(restored.type, MessageType.voice);
    });

    test('fromJson handles missing type with default', () {
      final json = {
        'id': 'def-456',
        'text': 'Test',
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.type, MessageType.text); // default
    });

    test('fromJson handles invalid timestamp', () {
      final json = {
        'id': 'ts-test',
        'text': 'Test',
        'isUser': true,
        'timestamp': 'invalid-date',
        'type': 'text',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.timestamp, isNotNull); // Falls back to DateTime.now()
    });

    test('fromJson handles null fields with defaults', () {
      final json = <String, dynamic>{};
      final msg = ChatMessage.fromJson(json);
      expect(msg.id, isNotEmpty);
      expect(msg.text, '');
      expect(msg.isUser, isFalse);
      expect(msg.type, MessageType.text);
    });

    test('equality based on id', () {
      final msg1 = ChatMessage(id: 'same-id', text: 'Hello', isUser: true);
      final msg2 = ChatMessage(id: 'same-id', text: 'Different', isUser: false);
      expect(msg1 == msg2, isTrue);
      expect(msg1.hashCode, msg2.hashCode);
    });

    test('different ids are not equal', () {
      final msg1 = ChatMessage(id: 'id-1', text: 'Hello', isUser: true);
      final msg2 = ChatMessage(id: 'id-2', text: 'Hello', isUser: true);
      expect(msg1 == msg2, isFalse);
    });

    test('MessageType enum names', () {
      expect(MessageType.text.name, 'text');
      expect(MessageType.system.name, 'system');
      expect(MessageType.error.name, 'error');
      expect(MessageType.voice.name, 'voice');
    });

    test('fromJson roundtrip for all message types', () {
      for (final type in MessageType.values) {
        final msg = ChatMessage(
          id: 'type-test-${type.name}',
          text: '${type.name} message',
          isUser: type == MessageType.text,
          type: type,
        );
        final json = msg.toJson();
        final restored = ChatMessage.fromJson(json);
        expect(restored.type, type, reason: 'Type $type did not roundtrip correctly');
      }
    });
  });
}
