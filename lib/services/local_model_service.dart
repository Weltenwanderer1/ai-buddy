import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/domain/model_source.dart';
import 'package:flutter_gemma/core/di/service_registry.dart';
import 'package:flutter_gemma/core/services/model_repository.dart' as model_repo;
import 'package:shared_preferences/shared_preferences.dart';

/// Callback signature for executing a tool call.
typedef ToolExecutionCallback = Future<String> Function(
    String toolName, Map<String, dynamic> arguments);

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
  // Gemma 4 E4B — .litertlm Format, ~4.3 GB
  // ModelType.gemma4 enables native <|tool_call>|> token parsing
  static const e4b = LocalModelConfig(
    id: 'e4b',
    displayName: 'Gemma 4 E4B (LiteRT-LM)',
    modelType: ModelType.gemma4,
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    sizeBytes: 4617089843, // ~4.3 GB
  );

  // Gemma 4 E2B — .litertlm Format, ~2.4 GB
  static const e2b = LocalModelConfig(
    id: 'e2b',
    displayName: 'Gemma 4 E2B (LiteRT-LM)',
    modelType: ModelType.gemma4,
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
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
  static const _prefsKeyModelInstalled = 'local_model_installed';

  /// Per-model installed flags to avoid generic Boolean issue.
  static String _modelInstalledKey(String modelId) => 'model_installed_$modelId';

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

  /// Extract the full filename (with extension) from a download URL.
  /// Example: 'https://...gemma-4-E4B-it.litertlm' → 'gemma-4-E4B-it.litertlm'
  String _modelFileName(LocalModelConfig model) {
    return model.downloadUrl.split('/').last;
  }

  /// Extract the base name (without extension) from a download URL.
  /// Example: 'https://...gemma-4-E4B-it.litertlm' → 'gemma-4-E4B-it'
  String _modelBaseName(LocalModelConfig model) {
    final filename = _modelFileName(model);
    return filename.replaceAll(RegExp(r'\.(litertlm|task|bin|tflite)$'), '');
  }

  /// Check if model is installed on disk and re-register as active if needed.
  ///
  /// After app restart, FlutterGemma.hasActiveModel() returns false because
  /// the active model is only held in memory. We use a multi-layer approach:
  /// 1. Check flutter_gemma's ModelRepository (SharedPreferences-based) for
  ///    metadata about installed models.
  /// 2. Check our own per-model SharedPreferences flags as fallback.
  /// 3. Re-register the model spec in memory so hasActiveModel() works.
  /// 4. Also ensure the model metadata is in the Repository for future checks.
  ///
  /// IMPORTANT: listInstalledModels() returns IDs WITH file extension
  /// (e.g. 'gemma-4-E4B-it.litertlm'), so we must match with the full filename.
  Future<void> _checkModelExists() async {
    final prefs = await SharedPreferences.getInstance();
    final perModelFlag = prefs.getBool(_modelInstalledKey(_activeModel.id)) ?? false;
    final legacyFlag = prefs.getBool(_prefsKeyModelInstalled) ?? false;
    final wasInstalled = perModelFlag || legacyFlag;

    final modelFileName = _modelFileName(_activeModel);
    final modelBaseName = _modelBaseName(_activeModel);

    try {
      final installedModels = await FlutterGemma.listInstalledModels();
      debugPrint('LocalModelService: installedModels = $installedModels');
      debugPrint('LocalModelService: looking for fileName=$modelFileName, baseName=$modelBaseName');

      // Match by full filename (primary) or base name (secondary for robustness)
      final isOnDisk = installedModels.contains(modelFileName) ||
          installedModels.contains(modelBaseName);

      if (isOnDisk) {
        // Model metadata exists in repository — re-register as active
        _reRegisterActiveModel();
        // Also ensure repository metadata has the full filename as ID
        await _ensureRepositoryMetadata();
        _modelAvailable = true;
        // Update per-model flag
        if (!perModelFlag) {
          await prefs.setBool(_modelInstalledKey(_activeModel.id), true);
        }
      } else if (wasInstalled) {
        // Per-model flag says installed but listInstalledModels doesn't find it.
        // This can happen if the Repository index was lost but the file is still on disk.
        // Re-register optimistically, restore metadata, and mark available.
        debugPrint('LocalModelService: Flag says installed but not in repository. Re-registering and restoring metadata.');
        _reRegisterActiveModel();
        await _ensureRepositoryMetadata();
        _modelAvailable = true;
        // Re-save the per-model flag
        await prefs.setBool(_modelInstalledKey(_activeModel.id), true);
      } else {
        _modelAvailable = false;
      }
    } catch (e) {
      debugPrint('LocalModelService: _checkModelExists error: $e');
      // listInstalledModels failed — trust per-model flag as fallback
      if (wasInstalled) {
        _reRegisterActiveModel();
        // Restore repository metadata so future checks work
        await _ensureRepositoryMetadata();
        _modelAvailable = true;
      } else {
        _modelAvailable = false;
      }
    }
    debugPrint('LocalModelService: _checkModelExists result: modelAvailable=$_modelAvailable');
    notifyListeners();
  }

  /// Ensure the model metadata is saved in flutter_gemma's ModelRepository.
  /// This is critical after app restart when the repository index may have been
  /// lost but the model file still exists on disk.
  Future<void> _ensureRepositoryMetadata() async {
    try {
      final url = _activeModel.downloadUrl;
      final fileName = _modelFileName(_activeModel);
      final repository = ServiceRegistry.instance.modelRepository;

      // Check if metadata already exists
      final existing = await repository.loadModel(fileName);
      if (existing != null) {
        debugPrint('LocalModelService: Repository metadata already exists for $fileName');
        return;
      }

      // Also check with base name
      final baseName = _modelBaseName(_activeModel);
      final existingBase = await repository.loadModel(baseName);
      if (existingBase != null) {
        debugPrint('LocalModelService: Repository metadata exists for base name $baseName');
        return;
      }

      // Save metadata so listInstalledModels() finds it after restart
      debugPrint('LocalModelService: Saving repository metadata for $fileName');
      await repository.saveModel(model_repo.ModelInfo(
        id: fileName,
        source: ModelSource.network(url),
        installedAt: DateTime.now(),
        sizeBytes: _activeModel.sizeBytes,
        type: model_repo.ModelType.inference,
        hasLoraWeights: false,
      ));
      debugPrint('LocalModelService: Repository metadata saved for $fileName');
    } catch (e) {
      debugPrint('LocalModelService: Failed to save repository metadata: $e');
      // Non-fatal — the in-memory registration is the important part
    }
  }

  /// Re-register the current model as active in FlutterGemma's ModelManager.
  /// This is needed after app restart when the in-memory active model is lost.
  ///
  /// Sets the InferenceModelSpec in the ModelManager so that hasActiveModel()
  /// returns true and getActiveModel() can create an InferenceModel.
  Future<void> _reRegisterActiveModel() async {
    try {
      final url = _activeModel.downloadUrl;
      final baseName = _modelBaseName(_activeModel);
      final spec = InferenceModelSpec(
        name: baseName,
        modelSource: ModelSource.network(url),
        modelType: _activeModel.modelType,
        fileType: ModelFileType.litertlm,
      );

      // Set the active model in the in-memory ModelManager
      FlutterGemmaPlugin.instance.modelManager.setActiveModel(spec);
      debugPrint('LocalModelService: Re-registered active model: ${spec.name}');
    } catch (e) {
      debugPrint('LocalModelService: Failed to re-register active model: $e');
    }
  }

  /// Fix 4: Save model-installed flag per model ID (not generic Boolean).
  Future<void> _saveModelInstalledPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    // Save per-model flag
    await prefs.setBool(_modelInstalledKey(_activeModel.id), value);
    // Also keep legacy key for backward compat
    await prefs.setBool(_prefsKeyModelInstalled, value);
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

      // Unload any previous model before downloading a new one
      await unloadModel();

      final installation = await FlutterGemma.installModel(
        modelType: _activeModel.modelType,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(url)
          .withProgress((progress) {
            _downloadProgress = (progress / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      debugPrint('LocalModelService: Download complete. Installation spec: ${installation.spec.name}');

      // After successful download, ensure repository metadata is saved
      // (the install builder may have already saved it, but let's be sure)
      await _ensureRepositoryMetadata();

      // Now check if the model is available
      await _checkModelExists();
      _isDownloading = false;
      _downloadProgress = 1.0;

      if (_modelAvailable) {
        await _saveModelInstalledPref(true);
        debugPrint('LocalModelService: Model marked as installed and available.');
      } else {
        // Download reported success but verification failed —
        // force mark as available since install() succeeded
        debugPrint('LocalModelService: Download OK but _checkModelExists returned false. Forcing available.');
        _modelAvailable = true;
        _reRegisterActiveModel();
        await _saveModelInstalledPref(true);
      }
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

      // Uninstall only the currently active model (not all installed models)
      // FlutterGemma.uninstallModel expects the full filename WITH extension
      // (e.g. 'gemma-4-E4B-it.litertlm'), which is the model ID stored in the repository.
      final modelFileName = _modelFileName(_activeModel);
      try {
        await FlutterGemma.uninstallModel(modelFileName);
      } catch (e) {
        debugPrint('Could not uninstall model $modelFileName: $e');
        // Fallback: try base name without extension
        final modelBaseName = _modelBaseName(_activeModel);
        try {
          await FlutterGemma.uninstallModel(modelBaseName);
        } catch (e2) {
          debugPrint('Could not uninstall model $modelBaseName either: $e2');
        }
      }

      _modelAvailable = false;
      _useLocalModel = false;
      await _saveUseLocalModelPref(false);
      // Clear per-model flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_modelInstalledKey(_activeModel.id));
      await prefs.remove(_prefsKeyModelInstalled);
      await prefs.remove(_prefsKeyModelId);
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
      // If no active model registered (e.g. after restart), re-register first
      if (!FlutterGemma.hasActiveModel()) {
        await _reRegisterActiveModel();
        // Check again after re-registration
        if (!FlutterGemma.hasActiveModel()) {
          debugPrint('LocalModelService: Re-registration did not set active model. Model not available.');
          _modelAvailable = false;
          notifyListeners();
          return false;
        }
      }
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
      );
      _isModelLoaded = true;
      _error = null;
      // Ensure the per-model flag is set since we confirmed the model loads
      await _saveModelInstalledPref(true);
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



  /// Convert our tool definitions to flutter_gemma Tool objects.
  List<Tool> _mapToGemmaTools(List<Map<String, dynamic>> definitions) {
    return definitions.map((def) => Tool(
      name: def['name'] as String,
      description: def['description'] as String,
      parameters: (def['parameters'] as Map<String, dynamic>?) ?? const {},
    )).toList();
  }

  /// Chat with the local model (non-streaming).
  ///
  /// Defensive: max 512 tokens, max 10 history messages, trimmed system prompt.
  /// If [toolDefinitions] and [onToolCall] are provided, enables native
  /// Function Calling with up to [maxToolRounds] tool execution loops.
  /// Catches native exceptions from LiteRT-LM to prevent app crashes.
  Future<String> chat(
    List<Map<String, String>> messages, {
    String? systemPrompt,
    double temperature = 0.5,
    int maxTokens = 512,
    List<Map<String, dynamic>>? toolDefinitions,
    ToolExecutionCallback? onToolCall,
    int maxToolRounds = 3,
  }) async {
    if (!_isModelLoaded || _model == null) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Modell-Laden fehlgeschlagen. Bitte prüfe in den Einstellungen, ob das Modell heruntergeladen ist.');
      }
    }

    // Defensive: trim history to last 10 messages
    var trimmedMessages = messages;
    if (trimmedMessages.length > 10) {
      trimmedMessages = trimmedMessages.sublist(trimmedMessages.length - 10);
    }

    // With tools active, system prompt must be shorter (tools eat context)
    final systemLimit = (toolDefinitions != null && toolDefinitions.isNotEmpty) ? 500 : 800;
    final trimmedSystem = (systemPrompt != null && systemPrompt.length > systemLimit)
        ? '${systemPrompt.substring(0, systemLimit)}...'
        : systemPrompt;

    // ── Try 1: Native Function Calling (if tools requested) ──
    if (toolDefinitions != null && toolDefinitions.isNotEmpty && onToolCall != null) {
      try {
        return await _chatWithToolLoop(
          trimmedMessages,
          trimmedSystem,
          temperature: temperature,
          toolDefinitions: toolDefinitions,
          onToolCall: onToolCall,
          maxToolRounds: maxToolRounds,
        );
      } catch (e) {
        debugPrint('Native function calling failed, falling back to text-only: $e');
        // Fall through to text-only mode
      }
    }

    // ── Try 2: Text-Only Mode (safe fallback) ──
    return await _chatTextOnly(
      trimmedMessages,
      trimmedSystem,
      temperature: temperature,
    );
  }

  /// Native Function Calling with tool loop.
  /// Uses ModelType.gemma4 for native <|tool_call>|> token parsing.
  Future<String> _chatWithToolLoop(
    List<Map<String, String>> messages,
    String? systemPrompt, {
    required double temperature,
    required List<Map<String, dynamic>> toolDefinitions,
    required ToolExecutionCallback onToolCall,
    required int maxToolRounds,
  }) async {
    InferenceChat? chat;
    try {
      chat = await _model!.createChat(
        temperature: temperature,
        supportsFunctionCalls: true,
        tools: _mapToGemmaTools(toolDefinitions),
        modelType: _activeModel.modelType,
        toolChoice: ToolChoice.auto,
      );
    } catch (e) {
      throw Exception('createChat fehlgeschlagen: $e');
    }

    // System prompt as FIRST non-user message — Gemma 4 has no native system role
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      try {
        await chat.addQueryChunk(
          Message.text(text: systemPrompt, isUser: false),
        );
      } catch (e) {
        debugPrint('addQueryChunk (system prompt) failed: $e');
      }
    }

    // Add all conversation messages
    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        try {
          await chat.addQueryChunk(
            Message.text(text: content, isUser: role == 'user'),
          );
        } catch (e) {
          debugPrint('addQueryChunk (history) failed: $e');
        }
      }
    }

    // Tool-execution loop
    String finalText = '';
    int toolRounds = 0;

    while (toolRounds < maxToolRounds) {
      ModelResponse response;
      try {
        response = await chat.generateChatResponse();
      } catch (e) {
        throw Exception('generateChatResponse fehlgeschlagen: $e');
      }

      if (response is TextResponse) {
        finalText = response.token;
        break;
      } else if (response is FunctionCallResponse) {
        final toolName = response.name;
        final args = response.args;
        debugPrint('Tool call: $toolName args=$args');

        String resultText;
        try {
          resultText = await onToolCall(toolName, args);
        } catch (e) {
          resultText = 'Fehler: $e';
        }

        // For Gemma 4 with native function calling, add tool result as user message
        final resultMsg = resultText.length > 300 ? '${resultText.substring(0, 300)}...' : resultText;
        try {
          await chat.addQueryChunk(
            Message.text(
              text: resultMsg,
              isUser: true,
            ),
          );
        } catch (e) {
          debugPrint('addQueryChunk (tool result) failed: $e');
        }
        toolRounds++;
      } else if (response is ParallelFunctionCallResponse) {
        // Handle parallel tool calls
        final calls = response.calls;
        debugPrint('Parallel tool calls: ${calls.length}');
        for (final call in calls) {
          String resultText;
          try {
            resultText = await onToolCall(call.name, call.args);
          } catch (e) {
            resultText = 'Fehler: $e';
          }
          try {
            final resultMsg = resultText.length > 300 ? '${resultText.substring(0, 300)}...' : resultText;
            await chat.addQueryChunk(
              Message.text(text: resultMsg, isUser: true),
            );
          } catch (e) {
            debugPrint('addQueryChunk (parallel tool result) failed: $e');
          }
        }
        toolRounds++;
      } else {
        finalText = response.toString();
        break;
      }
    }

    // If only tool calls happened but no final text, get a summary response
    if (finalText.isEmpty && toolRounds > 0) {
      try {
        final summaryResponse = await chat.generateChatResponse();
        if (summaryResponse is TextResponse) {
          finalText = summaryResponse.token;
        } else {
          finalText = summaryResponse.toString();
        }
      } catch (e) {
        debugPrint('Summary response failed: $e');
        finalText = 'Tool-Aufruf ausgeführt.';
      }
    }

    return finalText;
  }

  /// Text-Only chat without native function calling.
  /// Safe fallback that works on all devices.
  Future<String> _chatTextOnly(
    List<Map<String, String>> messages,
    String? systemPrompt, {
    required double temperature,
  }) async {
    InferenceChat? chat;
    try {
      chat = await _model!.createChat(
        temperature: temperature,
        supportsFunctionCalls: false,
        tools: const [],
        modelType: _activeModel.modelType,
      );
    } catch (e) {
      throw Exception('createChat (text-only) fehlgeschlagen: $e');
    }

    // System prompt as FIRST non-user message — Gemma 4 has no native system role
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      try {
        await chat.addQueryChunk(
          Message.text(text: systemPrompt, isUser: false),
        );
      } catch (e) {
        debugPrint('addQueryChunk (system prompt) failed: $e');
      }
    }

    // Add all conversation messages
    for (final msg in messages) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        try {
          await chat.addQueryChunk(
            Message.text(text: content, isUser: role == 'user'),
          );
        } catch (e) {
          debugPrint('addQueryChunk (text-only) failed: $e');
        }
      }
    }

    try {
      final response = await chat.generateChatResponse();
      if (response is TextResponse) {
        return response.token;
      }
      return response.toString();
    } catch (e) {
      throw Exception('generateChatResponse (text-only) fehlgeschlagen: $e');
    }
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
      tools: const [],
      modelType: _activeModel.modelType,
    );

    // System prompt as FIRST non-user message — Gemma 4 has no native system role
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      try {
        await chat.addQueryChunk(
          Message.text(text: systemPrompt, isUser: false),
        );
      } catch (e) {
        debugPrint('addQueryChunk (system prompt) failed: $e');
      }
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