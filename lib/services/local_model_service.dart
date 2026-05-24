import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

/// Service für lokales KI-Modell (Gemma 4 E2B).
/// Verwaltet Download, Speicherort und lokale Inferenz via llama.cpp.
class LocalModelService extends ChangeNotifier {
  static const _modelFileName = 'gemma-4-E2B-it-Q4_K_M.gguf';
  static const _downloadUrl =
      'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf';
  static const _modelSizeBytes = 3717059584; // ~3.46 GB Q4_K_M
  static const _modelDisplayName = 'Gemma 4 E2B (Q4_K_M)';

  LlamaController? _controller;
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isDeleting = false;
  double _downloadProgress = 0.0;
  String? _modelPath;
  String? _error;
  bool _useLocalModel = false;

  CancelToken? _cancelToken;

  bool get isModelLoaded => _isModelLoaded;
  bool get isDownloading => _isDownloading;
  bool get isDeleting => _isDeleting;
  double get downloadProgress => _downloadProgress;
  String? get modelPath => _modelPath;
  String? get error => _error;
  bool get useLocalModel => _useLocalModel;
  bool get isModelAvailable => _modelPath != null;

  String get modelDisplayName => _modelDisplayName;
  String get downloadUrl => _downloadUrl;
  String get modelFileName => _modelFileName;
  int get modelSizeBytes => _modelSizeBytes;

  String get modelSizeDisplay {
    const gb = _modelSizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  LocalModelService() { _init(); }

  Future<void> _init() async {
    await _checkModelExists();
    await _loadUseLocalModelPref();
  }

  Future<String> _getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/models';
  }

  Future<String> _getModelFilePath() async {
    final dir = await _getModelDir();
    return '$dir/$_modelFileName';
  }

  Future<void> _checkModelExists() async {
    final path = await _getModelFilePath();
    final file = File(path);
    if (await file.exists() && await file.length() > 1000000) {
      _modelPath = path;
    } else {
      _modelPath = null;
    }
    notifyListeners();
  }

  Future<bool> hasEnoughFreeSpace() async {
    try {
      final dir = await _getModelDir();
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final testFile = File('$dir/.space_check');
      try {
        await testFile.writeAsBytes(List.filled(1024, 0));
        await testFile.delete();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> downloadModel() async {
    if (_isDownloading) return false;

    final hasSpace = await hasEnoughFreeSpace();
    if (!hasSpace) {
      _error = 'Nicht genug Speicherplatz. Mindestens 4 GB frei benötigt.';
      notifyListeners();
      return false;
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _error = null;
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      final dir = await _getModelDir();
      await Directory(dir).create(recursive: true);
      final filePath = '$dir/$_modelFileName';

      final dio = Dio();
      await dio.download(
        _downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
          } else {
            _downloadProgress = (received / _modelSizeBytes).clamp(0.0, 0.99);
          }
          notifyListeners();
        },
        deleteOnError: true,
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      final file = File(filePath);
      if (await file.exists() && await file.length() > 1000000) {
        _modelPath = filePath;
        _isDownloading = false;
        _downloadProgress = 1.0;
        notifyListeners();
        return true;
      } else {
        await file.delete().catchError((_) => File(''));
        _error = 'Download fehlgeschlagen: Datei ist beschädigt.';
        _isDownloading = false;
        _downloadProgress = 0.0;
        notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _error = null;
      } else {
        _error = 'Download-Fehler: ${e.message}';
        _isDownloading = false;
        _downloadProgress = 0.0;
      }
      try {
        final filePath = await _getModelFilePath();
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Download-Fehler: $e';
      _isDownloading = false;
      _downloadProgress = 0.0;
      try {
        final filePath = await _getModelFilePath();
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      notifyListeners();
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('Benutzer abgebrochen');
  }

  Future<bool> deleteModel() async {
    if (_isDeleting) return false;

    _isDeleting = true;
    _error = null;
    notifyListeners();

    try {
      await unloadModel();

      final filePath = await _getModelFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      _modelPath = null;
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
      _isDeleting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Löschen fehlgeschlagen: $e';
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadUseLocalModelPref() async {
    final prefs = await SharedPreferences.getInstance();
    _useLocalModel = prefs.getBool('use_local_model') ?? false;
    if (_useLocalModel && _modelPath == null) {
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
    }
    notifyListeners();
  }

  Future<void> _saveUseLocalModelPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_local_model', value);
  }

  Future<void> setUseLocalModel(bool value) async {
    if (value && _modelPath == null) return;
    _useLocalModel = value;
    await _saveUseLocalModelPref(value);
    if (!value) {
      await unloadModel();
    }
    notifyListeners();
  }

  Future<bool> loadModel() async {
    if (_isModelLoaded && _controller != null) return true;
    if (_modelPath == null) return false;

    try {
      _controller = LlamaController();

      int gpuLayers = 0;
      try {
        final gpuInfo = await _controller!.detectGpu();
        if (gpuInfo.vulkanSupported && gpuInfo.recommendedGpuLayers > 0) {
          gpuLayers = gpuInfo.recommendedGpuLayers;
        }
      } catch (_) {
        gpuLayers = 0;
      }

      await _controller!.loadModel(
        modelPath: _modelPath!,
        gpuLayers: gpuLayers,
        threads: 4,
        contextSize: 2048,
      );

      _isModelLoaded = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Modell laden fehlgeschlagen: $e';
      _isModelLoaded = false;
      _controller = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> unloadModel() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    _isModelLoaded = false;
    notifyListeners();
  }

  Future<String> chat(
    List<Map<String, String>> messages, {
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    if (!_isModelLoaded || _controller == null) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Lokales Modell konnte nicht geladen werden.');
      }
    }

    final prompt = _buildGemmaPrompt(messages);

    final buffer = StringBuffer();
    final completer = Completer<String>();

    _controller!.generate(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
    ).listen(
      (token) => buffer.write(token),
      onDone: () => completer.complete(buffer.toString()),
      onError: (error) => completer.completeError(error),
      cancelOnError: true,
    );

    return completer.future;
  }

  String _buildGemmaPrompt(List<Map<String, String>> messages) {
    final parts = <String>[];
    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (role == 'system') {
        parts.add('<start_of_turn>user\n$content<end_of_turn>');
      } else if (role == 'user') {
        parts.add('<start_of_turn>user\n$content<end_of_turn>');
      } else if (role == 'assistant') {
        parts.add('<start_of_turn>model\n$content<end_of_turn>');
      }
    }
    parts.add('<start_of_turn>model\n');
    return parts.join('\n');
  }

  @override
  void dispose() {
    unloadModel();
    super.dispose();
  }
}
