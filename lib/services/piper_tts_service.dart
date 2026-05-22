import 'dart:io';
import 'package:flutter/material.dart';
import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Available German Piper voice models for download.
enum PiperVoice {
  thorsten('de_DE-thorsten-high', 'Thorsten (Männlich, natürlich)',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high/de_DE-thorsten-high.onnx',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high/de_DE-thorsten-high.onnx.json'),
  eva('de_DE-eva-medium', 'Eva (Weiblich, klar)',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/eva/medium/de_DE-eva-medium.onnx',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/eva/medium/de_DE-eva-medium.onnx.json'),
  karl('de_DE-karl-medium', 'Karl (Männlich, tief)',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/karl/medium/de_DE-karl-medium.onnx',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/karl/medium/de_DE-karl-medium.onnx.json'),
  ramona('de_DE-ramona-low', 'Ramona (Weiblich, leicht)',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/ramona/low/de_DE-ramona-low.onnx',
    'https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/ramona/low/de_DE-ramona-low.onnx.json');

  final String id;
  final String displayName;
  final String modelUrl;
  final String configUrl;
  const PiperVoice(this.id, this.displayName, this.modelUrl, this.configUrl);

  /// Find voice by id string.
  static PiperVoice? fromId(String id) {
    for (final v in PiperVoice.values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

/// Service for offline Piper TTS — synthesizes text to speech entirely on-device.
class PiperTtsService extends ChangeNotifier {
  final PiperTtsPlugin _piper = PiperTtsPlugin();
  bool _isLoaded = false;

  /// Which voice is currently downloading (null = none downloading).
  PiperVoice? _downloadingVoice;
  double _downloadProgress = 0.0;
  String? _lastError;
  PiperVoice? _currentVoice;

  /// Cache of download status per voice.
  final Map<String, bool> _downloadedCache = {};

  bool get isLoaded => _isLoaded;
  bool get isDownloading => _downloadingVoice != null;
  double get downloadProgress => _downloadProgress;
  String? get lastError => _lastError;
  PiperVoice? get currentVoice => _currentVoice;
  bool get isAvailable => _isLoaded;

  /// Whether a specific voice is currently being downloaded.
  bool isDownloadingVoice(PiperVoice voice) => _downloadingVoice == voice;

  /// Get the local directory where Piper voice models are stored.
  Future<Directory> _getModelsDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/piper_voices');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Check if a voice model is already downloaded locally.
  Future<bool> isVoiceDownloaded(PiperVoice voice) async {
    if (_downloadedCache.containsKey(voice.id)) return _downloadedCache[voice.id]!;
    final dir = await _getModelsDir();
    final modelFile = File('${dir.path}/${voice.id}.onnx');
    final configFile = File('${dir.path}/${voice.id}.onnx.json');
    final exists = await modelFile.exists() && await configFile.exists();
    _downloadedCache[voice.id] = exists;
    return exists;
  }

  /// Refresh download status for a voice (call after download/delete).
  Future<void> _refreshDownloadStatus(PiperVoice voice) async {
    final dir = await _getModelsDir();
    final modelFile = File('${dir.path}/${voice.id}.onnx');
    final configFile = File('${dir.path}/${voice.id}.onnx.json');
    _downloadedCache[voice.id] = await modelFile.exists() && await configFile.exists();
  }

  /// Get file sizes for a voice (model + config), returns total bytes or null if not downloaded.
  Future<int?> getVoiceSize(PiperVoice voice) async {
    final dir = await _getModelsDir();
    final modelFile = File('${dir.path}/${voice.id}.onnx');
    final configFile = File('${dir.path}/${voice.id}.onnx.json');
    if (!await modelFile.exists()) return null;
    final modelSize = await modelFile.length();
    final configSize = await configFile.length();
    return modelSize + configSize;
  }

  /// Download a Piper voice model + config to local storage.
  /// Reports progress via [onProgress] (0.0 - 1.0).
  Future<bool> downloadVoice(PiperVoice voice, {void Function(double progress)? onProgress}) async {
    if (_downloadingVoice != null) return false; // another download in progress
    _downloadingVoice = voice;
    _downloadProgress = 0.0;
    _lastError = null;
    notifyListeners();

    try {
      final dir = await _getModelsDir();
      final modelFile = File('${dir.path}/${voice.id}.onnx');
      final configFile = File('${dir.path}/${voice.id}.onnx.json');

      // Download model with progress
      debugPrint('PiperTts: Downloading model ${voice.id}...');
      final modelResponse = await http.Client().send(http.Request('GET', Uri.parse(voice.modelUrl)));
      final modelTotal = modelResponse.contentLength ?? 1;
      int modelDownloaded = 0;
      final modelSink = modelFile.openWrite();
      await for (final chunk in modelResponse.stream) {
        modelSink.add(chunk);
        modelDownloaded += chunk.length;
        _downloadProgress = (modelDownloaded / modelTotal) * 0.9;
        notifyListeners();
        onProgress?.call(_downloadProgress);
      }
      await modelSink.close();
      debugPrint('PiperTts: Model downloaded ($modelDownloaded bytes)');

      // Download config
      debugPrint('PiperTts: Downloading config...');
      final configResponse = await http.get(Uri.parse(voice.configUrl));
      await configFile.writeAsBytes(configResponse.bodyBytes);
      _downloadProgress = 1.0;
      notifyListeners();
      onProgress?.call(1.0);

      await _refreshDownloadStatus(voice);
      debugPrint('PiperTts: Voice ${voice.id} downloaded successfully');
      _downloadingVoice = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Download fehlgeschlagen: $e';
      debugPrint('PiperTts: $_lastError');
      _downloadingVoice = null;
      notifyListeners();
      return false;
    }
  }

  /// Delete a downloaded voice model from local storage.
  Future<bool> deleteVoice(PiperVoice voice) async {
    try {
      // If this voice is currently loaded, unload it first
      if (_currentVoice == voice) {
        _isLoaded = false;
        _currentVoice = null;
        notifyListeners();
      }

      final dir = await _getModelsDir();
      final modelFile = File('${dir.path}/${voice.id}.onnx');
      final configFile = File('${dir.path}/${voice.id}.onnx.json');
      if (await modelFile.exists()) await modelFile.delete();
      if (await configFile.exists()) await configFile.delete();
      await _refreshDownloadStatus(voice);
      debugPrint('PiperTts: Voice ${voice.id} deleted');
      return true;
    } catch (e) {
      _lastError = 'Löschen fehlgeschlagen: $e';
      debugPrint('PiperTts: $_lastError');
      return false;
    }
  }

  /// Load a downloaded voice model into the Piper engine.
  Future<bool> loadVoice(PiperVoice voice) async {
    if (_isLoaded && _currentVoice == voice) return true; // Already loaded

    try {
      final dir = await _getModelsDir();
      final modelFile = File('${dir.path}/${voice.id}.onnx');
      final configFile = File('${dir.path}/${voice.id}.onnx.json');

      if (!await modelFile.exists() || !await configFile.exists()) {
        _lastError = 'Stimme ${voice.displayName} ist nicht heruntergeladen';
        debugPrint('PiperTts: $_lastError');
        return false;
      }

      debugPrint('PiperTts: Loading voice ${voice.id}...');
      await _piper.loadViaPath(
        modelPath: modelFile.path,
        configPath: configFile.path,
      );

      _isLoaded = true;
      _currentVoice = voice;
      _lastError = null;
      debugPrint('PiperTts: Voice ${voice.id} loaded successfully');
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Stimme laden fehlgeschlagen: $e';
      debugPrint('PiperTts: $_lastError');
      _isLoaded = false;
      notifyListeners();
      return false;
    }
  }

  /// Synthesize text to a WAV file. Returns the file path, or null on failure.
  Future<String?> synthesize(String text) async {
    if (!_isLoaded) {
      _lastError = 'Piper TTS nicht geladen';
      return null;
    }
    if (text.trim().isEmpty) {
      _lastError = 'Leerer Text';
      return null;
    }

    try {
      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/ai_buddy/piper_output.wav');
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }

      debugPrint('PiperTts: Synthesizing "${text.substring(0, text.length > 60 ? 60 : text.length)}…"');
      await _piper.synthesizeToFile(text: text, outputPath: outFile.path);
      debugPrint('PiperTts: Audio written to ${outFile.path}');
      return outFile.path;
    } catch (e) {
      _lastError = 'Sprachsynthese fehlgeschlagen: $e';
      debugPrint('PiperTts: $_lastError');
      return null;
    }
  }
}