import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

/// Konfiguration für ein verfügbares lokales Modell.
class LocalModelConfig {
  final String id;
  final String displayName;
  final String fileName;
  final String downloadUrl;
  final int sizeBytes;
  final String quantization;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.quantization,
  });

  String get sizeDisplay {
    final gb = sizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }
}

/// Verfügbare lokale Modelle.
class LocalModels {
  static const e4b = LocalModelConfig(
    id: 'e4b',
    displayName: 'Gemma 4 E4B (Q4_K_M)',
    fileName: 'gemma-4-E4B-it-Q4_K_M.gguf',
    downloadUrl: 'https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q4_K_M.gguf',
    sizeBytes: 4756340736, // ~4.43 GB
    quantization: 'Q4_K_M',
  );

  static const e2b = LocalModelConfig(
    id: 'e2b',
    displayName: 'Gemma 4 E2B (Q4_K_M)',
    fileName: 'gemma-4-E2B-it-Q4_K_M.gguf',
    downloadUrl: 'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf',
    sizeBytes: 3717059584, // ~3.46 GB
    quantization: 'Q4_K_M',
  );

  static const all = [e4b, e2b];

  static LocalModelConfig? byId(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Service für lokales KI-Modell.
/// Verwaltet Download, Speicherort und lokale Inferenz via llama.cpp.
class LocalModelService extends ChangeNotifier {
  static const _prefsKeyModelId = 'local_model_id';
  static const _prefsKeyUseLocal = 'use_local_model';

  LocalModelConfig _activeModel = LocalModels.e4b;

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

  LocalModelConfig get activeModel => _activeModel;
  String get modelDisplayName => _activeModel.displayName;
  String get downloadUrl => _activeModel.downloadUrl;
  String get modelFileName => _activeModel.fileName;
  int get modelSizeBytes => _activeModel.sizeBytes;
  String get modelSizeDisplay => _activeModel.sizeDisplay;
  String get quantization => _activeModel.quantization;
  List<LocalModelConfig> get availableModels => LocalModels.all;

  LocalModelService() { _init(); }

  Future<void> _init() async {
    await _loadModelIdPref();
    await _checkModelExists();
    await _loadUseLocalModelPref();
  }

  Future<void> _loadModelIdPref() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKeyModelId) ?? LocalModels.e4b.id;
    final model = LocalModels.byId(id);
    if (model != null) {
      _activeModel = model;
    }
  }

  Future<void> _saveModelIdPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyModelId, _activeModel.id);
  }

  Future<String> _getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/models';
  }

  Future<String> _getModelFilePath() async {
    final dir = await _getModelDir();
    return '$dir/${_activeModel.fileName}';
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

  /// Wechselt das aktive Modell (E4B oder E2B).
  Future<void> setActiveModel(LocalModelConfig model) async {
    if (_isDownloading) return;
    _activeModel = model;
    await _saveModelIdPref();
    await _checkModelExists();
    // If we switched and the new model isn't available, disable local mode
    if (_modelPath == null && _useLocalModel) {
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
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
      _error = 'Nicht genug Speicherplatz. Mindestens ${_activeModel.sizeDisplay} frei benötigt.';
      notifyListeners();
      return false;
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _error = null;
    _cancelToken = CancelToken();
    notifyListeners();

    // Keep screen awake during download
    await WakelockPlus.enable();

    try {
      final dir = await _getModelDir();
      await Directory(dir).create(recursive: true);
      final filePath = await _getModelFilePath();

      final dio = Dio();
      await dio.download(
        _activeModel.downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
          } else {
            _downloadProgress = (received / _activeModel.sizeBytes).clamp(0.0, 0.99);
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
      // Screen can sleep again
      await WakelockPlus.disable();
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
    _useLocalModel = prefs.getBool(_prefsKeyUseLocal) ?? false;
    if (_useLocalModel && _modelPath == null) {
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
    }
    notifyListeners();
  }

  Future<void> _saveUseLocalModelPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyUseLocal, value);
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

      // Sichere Defaults: CPU-only, weniger Ressourcen
      int gpuLayers = 0;
      int threads = 4;
      int contextSize = 2048;

      // GPU nur wenn explizit verfügbar und stabil
      try {
        final gpuInfo = await _controller!.detectGpu();
        if (gpuInfo.vulkanSupported && gpuInfo.recommendedGpuLayers > 0) {
          // Samsung + Mali GPUs sind oft instabil — lieber CPU
          gpuLayers = 0;
        }
      } catch (_) {
        gpuLayers = 0;
      }

      await _controller!.loadModel(
        modelPath: _modelPath!,
        gpuLayers: gpuLayers,
        threads: threads,
        contextSize: contextSize,
      );

      _isModelLoaded = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Modell laden fehlgeschlagen: $e';
      _isModelLoaded = false;
      try {
        await _controller?.dispose();
      } catch (_) {}
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
