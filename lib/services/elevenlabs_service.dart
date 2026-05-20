import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for ElevenLabs TTS (Text-to-Speech).
/// Reads config from SecureConfigService (injected).
class ElevenLabsService {
  String apiKey;
  String voiceId;
  String modelId;

  ElevenLabsService({
    required this.apiKey,
    required this.voiceId,
    this.modelId = 'eleven_multilingual_v2',
  });

  bool get isAvailable => apiKey.isNotEmpty && voiceId.isNotEmpty;

  /// Update config (e.g. after settings change).
  void updateConfig({String? apiKey, String? voiceId, String? modelId}) {
    if (apiKey != null) this.apiKey = apiKey;
    if (voiceId != null) this.voiceId = voiceId;
    if (modelId != null) this.modelId = modelId;
  }

  /// Synthesizes text to speech. Returns audio bytes (MP3).
  Future<List<int>> synthesize(String text) async {
    if (!isAvailable) {
      debugPrint('ElevenLabs: not available — apiKey=${apiKey.isEmpty ? "<empty>" : "***configured***"}, voiceId=${voiceId.isEmpty ? "<empty>" : voiceId}');
      return [];
    }

    debugPrint('ElevenLabs: synthesize(${text.length} chars) voice=$voiceId model=$modelId');

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': modelId,
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.8,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('ElevenLabs: received ${response.bodyBytes.length} bytes of audio');
        return response.bodyBytes;
      } else {
        debugPrint('ElevenLabs error: ${response.statusCode} — ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
        throw Exception('ElevenLabs error: ${response.statusCode} — ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      }
    } catch (e) {
      debugPrint('ElevenLabs synthesize exception: $e');
      rethrow;
    }
  }

  /// Test the ElevenLabs API connection.
  /// Returns a human-readable result message.
  Future<ElevenLabsTestResult> testConnection() async {
    if (apiKey.isEmpty) {
      return ElevenLabsTestResult(
        success: false,
        message: 'API Key nicht konfiguriert',
      );
    }
    if (voiceId.isEmpty) {
      return ElevenLabsTestResult(
        success: false,
        message: 'Voice ID nicht konfiguriert',
      );
    }

    try {
      // 1. Validate API key — fetch voices list
      final voicesResponse = await http.get(
        Uri.parse('https://api.elevenlabs.io/v1/voices'),
        headers: {'xi-api-key': apiKey},
      );

      if (voicesResponse.statusCode == 401) {
        return ElevenLabsTestResult(
          success: false,
          message: 'API Key ungültig (401 Unauthorized)',
        );
      }
      if (voicesResponse.statusCode != 200) {
        return ElevenLabsTestResult(
          success: false,
          message: 'Voices-Abfrage fehlgeschlagen: ${voicesResponse.statusCode}',
        );
      }

      // Parse voices and check if configured voiceId exists
      final voicesData = jsonDecode(voicesResponse.body);
      final voices = voicesData['voices'] as List<dynamic>? ?? [];
      final voiceNames = <String>{};
      bool voiceFound = false;
      for (final v in voices) {
        final id = v['voice_id'] as String? ?? '';
        final name = v['name'] as String? ?? '';
        voiceNames.add('$name ($id)');
        if (id == voiceId) voiceFound = true;
      }

      if (!voiceFound) {
        // Try to find voice by name (user might have entered name instead of ID)
        final voiceByName = voices.where(
          (v) => (v['name'] as String? ?? '').toLowerCase() == voiceId.toLowerCase(),
        );
        if (voiceByName.isNotEmpty) {
          return ElevenLabsTestResult(
            success: false,
            message: 'Voice ID "$voiceId" nicht gefunden. Meinst du "${voiceByName.first['name']}" (ID: ${voiceByName.first['voice_id']})?',
            availableVoices: voiceNames.toList(),
          );
        }
        return ElevenLabsTestResult(
          success: false,
          message: 'Voice ID "$voiceId" existiert nicht in deinem Account.',
          availableVoices: voiceNames.toList(),
        );
      }

      // 2. Test actual TTS synthesis with a short text
      const testText = 'Test.';
      final ttsResponse = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': testText,
          'model_id': modelId,
          'voice_settings': {'stability': 0.5, 'similarity_boost': 0.8},
        }),
      );

      if (ttsResponse.statusCode == 200) {
        return ElevenLabsTestResult(
          success: true,
          message: 'ElevenLabs funktioniert! Voice gefunden, TTS-Synthese erfolgreich (${ttsResponse.bodyBytes.length} Bytes Audio)',
          availableVoices: voiceNames.toList(),
        );
      } else {
        return ElevenLabsTestResult(
          success: false,
          message: 'Voice gültig aber TTS-Aufruf fehlgeschlagen: ${ttsResponse.statusCode} — ${ttsResponse.body.length > 200 ? ttsResponse.body.substring(0, 200) : ttsResponse.body}',
          availableVoices: voiceNames.toList(),
        );
      }
    } catch (e) {
      return ElevenLabsTestResult(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }
}

/// Result of an ElevenLabs connection test.
class ElevenLabsTestResult {
  final bool success;
  final String message;
  final List<String> availableVoices;

  ElevenLabsTestResult({
    required this.success,
    required this.message,
    this.availableVoices = const [],
  });
}
