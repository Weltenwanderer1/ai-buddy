import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/elevenlabs_service.dart';

void main() {
  group('ElevenLabsService', () {
    test('default model ID is eleven_flash_v2_5', () {
      final service = ElevenLabsService(apiKey: 'key', voiceId: 'voice');
      expect(service.modelId, 'eleven_flash_v2_5');
    });

    test('extracts raw voice ID when friendly name is included', () {
      final service = ElevenLabsService(
        apiKey: 'key',
        voiceId: 'Luna (21m00Tcm4TlvDq8ikWAM)',
      );
      expect(service.rawVoiceId, '21m00Tcm4TlvDq8ikWAM');
      expect(service.isAvailable, isTrue);
    });

    test('keeps raw voice ID unchanged when no parentheses are present', () {
      final service = ElevenLabsService(
        apiKey: 'key',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
      );
      expect(service.rawVoiceId, '21m00Tcm4TlvDq8ikWAM');
    });

    test('isAvailable returns false when API key or voiceId is empty', () {
      final service1 = ElevenLabsService(apiKey: '', voiceId: 'voice');
      expect(service1.isAvailable, isFalse);

      final service2 = ElevenLabsService(apiKey: 'key', voiceId: '');
      expect(service2.isAvailable, isFalse);

      final service3 = ElevenLabsService(apiKey: 'key', voiceId: '  (  )  ');
      expect(service3.isAvailable, isFalse);
    });
  });
}
