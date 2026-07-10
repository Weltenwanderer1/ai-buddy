import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Optional higher-quality cloud text-to-speech: OpenAI TTS or ElevenLabs.
///
/// Synthesizes text to an MP3 file (cached by text hash) which the playback
/// service plays back. The reply text is sent to the chosen provider — this is
/// opt-in and only used when the user selects the Cloud engine and supplies a
/// key. Returns null on any failure so the caller can fall back to device TTS.
class CloudTtsService {
  String provider; // 'openai' | 'elevenlabs'
  String openAiKey;
  String openAiVoice;
  String openAiModel;
  String elevenKey;
  String elevenVoice;
  String elevenModel;

  String? lastError;

  CloudTtsService({
    this.provider = 'openai',
    this.openAiKey = '',
    this.openAiVoice = 'alloy',
    this.openAiModel = 'tts-1',
    this.elevenKey = '',
    this.elevenVoice = 'JBFqnCBsd6RMkjVDRZzb',
    this.elevenModel = 'eleven_multilingual_v2',
  });

  void updateConfig({
    String? provider,
    String? openAiKey,
    String? openAiVoice,
    String? openAiModel,
    String? elevenKey,
    String? elevenVoice,
    String? elevenModel,
  }) {
    if (provider != null) this.provider = provider;
    if (openAiKey != null) this.openAiKey = openAiKey;
    if (openAiVoice != null && openAiVoice.isNotEmpty) this.openAiVoice = openAiVoice;
    if (openAiModel != null && openAiModel.isNotEmpty) this.openAiModel = openAiModel;
    if (elevenKey != null) this.elevenKey = elevenKey;
    if (elevenVoice != null && elevenVoice.isNotEmpty) this.elevenVoice = elevenVoice;
    if (elevenModel != null && elevenModel.isNotEmpty) this.elevenModel = elevenModel;
  }

  /// Whether the currently selected provider has a key configured.
  bool get isConfigured =>
      provider == 'elevenlabs' ? elevenKey.isNotEmpty : openAiKey.isNotEmpty;

  String get _voiceId => provider == 'elevenlabs' ? elevenVoice : openAiVoice;

  /// Synthesize [text] to a cached MP3 file. Returns the file path, or null.
  Future<String?> synthesizeToFile(String text) async {
    lastError = null;
    if (text.trim().isEmpty) return null;
    if (!isConfigured) {
      lastError = 'Kein API-Key für $provider hinterlegt';
      return null;
    }
    try {
      // Serve from cache when we've synthesized this exact text/voice before.
      final cacheDir = await _cacheDir();
      final cacheFile =
          File('${cacheDir.path}/${_hash('$provider|$_voiceId|$text')}.mp3');
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        return cacheFile.path;
      }

      final Uint8List bytes =
          provider == 'elevenlabs' ? await _elevenLabs(text) : await _openai(text);
      if (bytes.isEmpty) return null;

      await cacheFile.writeAsBytes(bytes, flush: true);
      return cacheFile.path;
    } catch (e) {
      lastError = 'Cloud-TTS Fehler: $e';
      return null;
    }
  }

  Future<Uint8List> _openai(String text) async {
    final res = await http
        .post(
          Uri.parse('https://api.openai.com/v1/audio/speech'),
          headers: {
            'Authorization': 'Bearer $openAiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': openAiModel.isEmpty ? 'tts-1' : openAiModel,
            'voice': openAiVoice.isEmpty ? 'alloy' : openAiVoice,
            'input': text,
            'response_format': 'mp3',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      lastError = 'OpenAI TTS HTTP ${res.statusCode}: ${_short(res.body)}';
      return Uint8List(0);
    }
    return res.bodyBytes;
  }

  Future<Uint8List> _elevenLabs(String text) async {
    final voice = elevenVoice.isEmpty ? 'JBFqnCBsd6RMkjVDRZzb' : elevenVoice;
    final res = await http
        .post(
          Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voice'),
          headers: {
            'xi-api-key': elevenKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': elevenModel.isEmpty ? 'eleven_multilingual_v2' : elevenModel,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      lastError = 'ElevenLabs HTTP ${res.statusCode}: ${_short(res.body)}';
      return Uint8List(0);
    }
    return res.bodyBytes;
  }

  Future<Directory> _cacheDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/ai_buddy/tts_cloud_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  String _short(String s) => s.length > 140 ? s.substring(0, 140) : s;

  String _hash(String text) {
    final bytes = text.codeUnits;
    var h = 0x1a2b3c4d;
    for (var i = 0; i < bytes.length; i++) {
      h = ((h ^ bytes[i]) * 0x5bd1e995 + (h >> 16)) & 0x7fffffff;
    }
    return h.toRadixString(36);
  }
}
