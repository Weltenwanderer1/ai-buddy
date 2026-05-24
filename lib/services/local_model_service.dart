import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Konfiguration für ein lokales Modell (LiteRT-LM Format).
class LocalModelConfig {
  final String id;
  final String displayName;
  final ModelType modelType;
  final String downloadUrl;
  final int sizeBytes;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.modelType,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  String get sizeDisplay {
    final gb = sizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }
}

/// Verfügbare lokale Modelle via flutter_gemma / LiteRT-LM.
class LocalModels {
  // Gemma 4 E4B — .litertlm Format (als task file type), ~4.3 GB
  static const e4b = LocalModelConfig(
    id: 'e4b',
    displayName: 'Gemma 4 E4B (LiteRT-LM)',
    modelType: ModelType.gemmaIt,
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it-litert-lm.litertlm',
    sizeBytes: 4617089843, // ~4.3 GB
  );

  // Gemma 4 E2B — .litertlm Format, ~2.4 GB
  static const e2b = LocalModelConfig(
    id: 'e2b',
    displayName: 'Gemma 4 E2B (LiteRT-LM)',
    modelType: ModelType.gemmaIt,
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-litert-lm.litertlm',
    sizeBytes: 2576980377, // ~2.4 GB
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

/// Service für lokales KI-Modell via flutter_gemma / LiteRT-LM.
///
/// Nutzt Google's LiteRT-LM Runtime mit GPU-Beschleunigung.
/// Stabil auf Samsung/Mali-Geräten — kein llama.cpp Vulkan-Crash.
class LocalModelService extends ChangeNotifier {
  static const _prefsKeyModelId = 'local_model_id';
  static const _prefsKeyUseLocal = 'use_local_model';

  LocalModelConfig _activeModel = LocalModels.e4b;

  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isDeleting = false;
  double _downloadProgress = 0.0;
  bool _modelAvailable = false;
  String? _error;
  bool _useLocalModel = false;

  InferenceModel? _model;

  bool get isModelLoaded => _isModelLoaded;
  bool get isDownloading => _isDownloading;
  bool get isDeleting => _isDeleting;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;
  bool get useLocalModel => _useLocalModel;
  bool get isModelAvailable => _modelAvailable;

  LocalModelConfig get activeModel => _activeModel;
  String get modelDisplayName => _activeModel.displayName;
  String get downloadUrl => _activeModel.downloadUrl;
  int get modelSizeBytes => _activeModel.sizeBytes;
  String get modelSizeDisplay => _activeModel.sizeDisplay;
  List<LocalModelConfig> get availableModels => LocalModels.all;

  LocalModelService() {
    _init();
  }

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

  Future<void> _checkModelExists() async {
    try {
      _modelAvailable = FlutterGemma.hasActiveModel();
    } catch (_) {
      _modelAvailable = false;
    }
    notifyListeners();
  }

  /// Wechselt das aktive Modell (E4B oder E2B).
  Future<void> setActiveModel(LocalModelConfig model) async {
    if (_isDownloading) return;
    _activeModel = model;
    await _saveModelIdPref();
    await _checkModelExists();
    if (!_modelAvailable && _useLocalModel) {
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
    }
    notifyListeners();
  }

  Future<bool> downloadModel() async {
    if (_isDownloading) return false;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final url = _activeModel.downloadUrl;
      final filename = url.split('/').last;

      await FlutterGemma.installModel(
        modelType: _activeModel.modelType,
        fileType: ModelFileType.task, // .litertlm handled as task format
      )
          .fromNetwork(url)
          .withProgress((progress) {
            _downloadProgress = (progress / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      await _checkModelExists();
      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();
      return _modelAvailable;
    } catch (e) {
      _error = 'Download-Fehler: $e';
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  void cancelDownload() {
    if (_isDownloading) {
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  Future<bool> deleteModel() async {
    if (_isDeleting) return false;

    _isDeleting = true;
    _error = null;
    notifyListeners();

    try {
      await unloadModel();

      // Get model ID from install system
      final models = await FlutterGemma.listInstalledModels();
      for (final modelId in models) {
        try {
          await FlutterGemma.uninstallModel(modelId);
        } catch (_) {}
      }

      _modelAvailable = false;
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
    if (_useLocalModel && !_modelAvailable) {
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
    if (value && !_modelAvailable) return;
    _useLocalModel = value;
    await _saveUseLocalModelPref(value);
    if (!value) {
      await unloadModel();
    }
    notifyListeners();
  }

  Future<bool> loadModel() async {
    if (_isModelLoaded && _model != null) return true;
    if (!_modelAvailable) return false;

    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
      );
      _isModelLoaded = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Modell laden fehlgeschlagen: $e';
      _isModelLoaded = false;
      _model = null;
      notifyListeners();
      return false;
    }
  }

  /// Chat with the local model (non-streaming).
  ///
  /// Uses flutter_gemma's InferenceChat with text history.
  Future<String> chat(
    List<Map<String, String>> messages, {
    String? systemPrompt,
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async {
    if (!_isModelLoaded || _model == null) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Lokales Modell konnte nicht geladen werden.');
      }
    }

    final chat = await _model!.createChat(
      temperature: temperature,
      supportsFunctionCalls: false,
    );

    // Add system prompt as first user message (Gemma chat template)
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      await chat.addQueryChunk(
        Message.text(text: 'System: $systemPrompt', isUser: true),
      );
    }

    // Add history (all messages)
    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        await chat.addQueryChunk(
          Message.text(
            text: content,
            isUser: role == 'user',
          ),
        );
      }
    }

    final response = await chat.generateChatResponse();
    final text = response is TextResponse
        ? response.token
        : response is FunctionCallResponse
            ? response.name
            : response.toString();

    return text;
  }

  /// Stream chat responses from the local model.
  ///
  /// Returns a stream of text tokens.
  Stream<String> streamChat(
    List<Map<String, String>> messages, {
    String? systemPrompt,
    double temperature = 0.3,
  }) async* {
    if (!_isModelLoaded || _model == null) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Lokales Modell konnte nicht geladen werden.');
      }
    }

    final chat = await _model!.createChat(
      temperature: temperature,
      supportsFunctionCalls: false,
    );

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      await chat.addQueryChunk(
        Message.text(text: 'System: $systemPrompt', isUser: true),
      );
    }

    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        await chat.addQueryChunk(
          Message.text(text: content, isUser: role == 'user'),
        );
      }
    }

    final stream = chat.generateChatResponseAsync();
    await for (final response in stream) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  Future<void> unloadModel() async {
    if (_model != null) {
      try {
        await _model!.close();
      } catch (_) {}
      _model = null;
    }
    _isModelLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unloadModel();
    super.dispose();
  }
}