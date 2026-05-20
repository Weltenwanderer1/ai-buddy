import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OpenRouter TTS via gpt-4o-mini-tts — uses the /api/v1/audio/speech endpoint
/// which is OpenAI-compatible. Returns raw MP3 bytes.
///
/// Available voices: alloy, ash, ballad, coral, echo, fable, nova, onyx, sage, shimmer, verse
/// (OpenAI TTS voices — check model page for current list)
class OpenRouterTtsService {
  String apiKey;
  final String baseUrl;
  String model;
  String voice;

  OpenRouterTtsService({
    required this.apiKey,
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.model = 'openai/gpt-4o-mini-tts-2025-12-15',
    this.voice = 'nova',
  });

  bool get isAvailable => apiKey.isNotEmpty;

  void updateConfig({String? apiKey, String? model, String? voice}) {
    if (apiKey != null) this.apiKey = apiKey;
    if (model != null) this.model = model;
    if (voice != null) this.voice = voice;
  }

  /// Synthesize text to speech. Returns MP3 audio bytes.
  Future<List<int>> synthesize(String text) async {
    if (!isAvailable) {
      debugPrint('OpenRouter TTS: not available — apiKey empty');
      return [];
    }
    if (text.trim().isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'input': text,
          'voice': voice,
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('OpenRouter TTS: received ${response.bodyBytes.length} bytes of audio');
        return response.bodyBytes;
      } else {
        final body = response.body.length > 500
            ? response.body.substring(0, 500)
            : response.body;
        debugPrint('OpenRouter TTS error: ${response.statusCode} — $body');
        throw Exception('OpenRouter TTS error: ${response.statusCode} — $body');
      }
    } catch (e) {
      debugPrint('OpenRouter TTS synthesize exception: $e');
      rethrow;
    }
  }

  /// Test the connection by making a short TTS request.
  Future<OpenRouterTtsTestResult> testConnection() async {
    if (apiKey.isEmpty) {
      return OpenRouterTtsTestResult(
        success: false,
        message: 'OpenRouter API Key nicht konfiguriert',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'input': 'Test.',
          'voice': voice,
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode == 200) {
        return OpenRouterTtsTestResult(
          success: true,
          message: 'OpenRouter TTS funktioniert! Modell: $model, Voice: $voice (${response.bodyBytes.length} Bytes Audio)',
        );
      } else {
        final body = response.body.length > 500
            ? response.body.substring(0, 500)
            : response.body;
        return OpenRouterTtsTestResult(
          success: false,
          message: 'Fehler: ${response.statusCode} — $body',
        );
      }
    } catch (e) {
      return OpenRouterTtsTestResult(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }
}

class OpenRouterTtsTestResult {
  final bool success;
  final String message;

  OpenRouterTtsTestResult({required this.success, required this.message});
}