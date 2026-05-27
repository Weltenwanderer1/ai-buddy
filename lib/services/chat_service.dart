import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/local_model_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/secure_config_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/self_identity_service.dart';
import '../services/location_service.dart';
import '../services/buddy_capabilities_service.dart';
import '../tools/tool_registry.dart';

/// Callback signature for executing a tool call via cloud LLM.
typedef ToolExecutionCallback = Future<String> Function(String toolName, Map<String, dynamic> arguments);

typedef ToolDisplayCallback = void Function(ChatMessage toolMessage);
typedef StreamingCallback = void Function(String partialText);

class ChatService {
  final LocalModelService _localModel;
  final OllamaCloudService? _cloudService;
  final SecureConfigService? _configService;
  final ToolRegistry? _toolRegistry;
  final SelfIdentityService? _selfIdentity;
  final LocationService? _locationService;
  final BuddyCapabilitiesService? _buddyCapabilities;
  int _messageCount = 0;
  static const int evolutionInterval = 10;

  ChatService(this._localModel, {OllamaCloudService? cloudService, SecureConfigService? configService, ToolRegistry? toolRegistry, SelfIdentityService? selfIdentity, LocationService? locationService, BuddyCapabilitiesService? buddyCapabilities})
      : _cloudService = cloudService,
        _configService = configService,
        _toolRegistry = toolRegistry,
        _selfIdentity = selfIdentity,
        _locationService = locationService,
        _buddyCapabilities = buddyCapabilities;

  /// Returns true if we should use the local model for inference.
  bool _useLocal() {
    final config = _configService;
    if (config == null) return _localModel.isModelAvailable;
    return config.llmProvider == 'local' && _localModel.isModelAvailable;
  }

  /// Returns true if we should use a cloud provider for inference.
  bool _useCloud() {
    final config = _configService;
    if (config == null) return false;
    final provider = config.llmProvider;
    return (provider == 'ollama' || provider == 'openrouter');
  }

  /// Get or create a cloud service instance based on current config.
  OllamaCloudService _getCloudService() {
    if (_cloudService != null) {
      // Update config from SecureConfigService if available
      final config = _configService;
      if (config != null) {
        _cloudService!.updateConfig(
          baseUrl: config.activeBaseUrl,
          apiKey: config.activeApiKey,
          defaultModel: config.activeModel,
          fallbackModel: config.activeFallbackModel,
        );
      }
      return _cloudService!;
    }
    // Fallback: create from config service
    final config = _configService!;
    return OllamaCloudService(
      baseUrl: config.activeBaseUrl,
      apiKey: config.activeApiKey,
      defaultModel: config.activeModel,
      fallbackModel: config.activeFallbackModel,
    );
  }

  // No longer used — model routing is handled via config, not regex heuristics

  Stream<String> streamResponse({
    required String userMessage,
    required PersonaService persona,
    required MemoryService memory,
    required List<ChatMessage> history,
    PersonaEvolutionService? personaEvolution,
    ToolDisplayCallback? onToolActivity,
  }) {
    final controller = StreamController<String>();

    Future<void> _run() async {
      try {
        final evolutionContext = personaEvolution?.buildEvolutionContext();
        var systemPrompt = await _buildSystemPrompt(
          persona, memory, userMessage,
          evolutionContext: evolutionContext,
        );

        final chatHistory = history
            .where((m) => m.type == MessageType.text || m.type == MessageType.voice)
            .toList();
        final windowedHistory = chatHistory.length > 10
            ? chatHistory.sublist(chatHistory.length - 10)
            : chatHistory;
        final messages = windowedHistory
            .map((m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                })
            .toList();

        final lastMsg = messages.isNotEmpty ? messages.last : null;
        final alreadyInHistory = lastMsg != null &&
            lastMsg['role'] == 'user' &&
            lastMsg['content'] == userMessage;
        if (!alreadyInHistory) {
          messages.add({'role': 'user', 'content': userMessage});
        }

        if (_useCloud()) {
          // ── Cloud inference path (Ollama/OpenRouter) ──
          try {
            final cloud = _getCloudService();

            // Tool execution callback for cloud tool calls
            Future<String> onCloudToolCall(String toolName, Map<String, dynamic> args) async {
              debugPrint('ChatService (cloud) executing tool: $toolName args=$args');
              if (onToolActivity != null) {
                onToolActivity(ChatMessage(
                  text: '🔧 $toolName...',
                  isUser: false,
                  type: MessageType.toolActivity,
                ));
              }
              final result = await _toolRegistry!.execute(toolName, args);
              if (onToolActivity != null && result.displayText != null) {
                onToolActivity(ChatMessage(
                  text: result.displayText!,
                  isUser: false,
                  type: MessageType.toolActivity,
                ));
              }
              return result.result;
            }

            // Build messages for cloud API
            final cloudMessages = messages.map((m) => {
              'role': m['role'] as String,
              'content': m['content'] as String,
            }).toList();

            if (_toolRegistry != null && _toolRegistry!.getToolDefinitions().isNotEmpty) {
              // Use chatWithTools for cloud tool support
              final chatResponse = await cloud.chatWithTools(
                systemPrompt: systemPrompt!,
                messages: cloudMessages.cast<Map<String, dynamic>>(),
                tools: _toolRegistry!.getToolDefinitions(),
                temperature: 0.5,
              );

              String reply;
              if (chatResponse.hasToolCalls) {
                // Execute tool calls in a loop
                reply = await _executeCloudToolLoop(
                  cloud: cloud,
                  systemPrompt: systemPrompt!,
                  messages: cloudMessages.cast<Map<String, dynamic>>(),
                  chatResponse: chatResponse,
                  onToolCall: onCloudToolCall,
                  maxRounds: 3,
                );
              } else {
                reply = chatResponse.content;
              }

              final words = reply.split(' ');
              for (int i = 0; i < words.length; i++) {
                if (controller.isClosed) break;
                controller.add((i == 0 ? '' : ' ') + words[i]);
              }
              await _saveMemory(memory, userMessage, reply);
              _maybeEvolve(personaEvolution, history, userMessage, reply);
            } else {
              // No tools — simple cloud chat
              final reply = await cloud.chat(
                systemPrompt: systemPrompt!,
                messages: cloudMessages.cast<Map<String, String>>(),
                temperature: 0.5,
              );
              final words = reply.split(' ');
              for (int i = 0; i < words.length; i++) {
                if (controller.isClosed) break;
                controller.add((i == 0 ? '' : ' ') + words[i]);
              }
              await _saveMemory(memory, userMessage, reply);
              _maybeEvolve(personaEvolution, history, userMessage, reply);
            }
          } catch (e) {
            debugPrint('Cloud model failed: $e');
            if (!controller.isClosed) {
              controller.add('Entschuldige, die Cloud-Verbindung hat ein Problem: $e');
            }
          }
        } else if (_useLocal()) {
          // ── Local inference path ──
          try {
            // Tool execution callback for Function Calling
            Future<String> onToolCall(String toolName, Map<String, dynamic> args) async {
              debugPrint('ChatService executing tool: $toolName args=$args');
              if (onToolActivity != null) {
                onToolActivity(ChatMessage(
                  text: '🔧 $toolName...',
                  isUser: false,
                  type: MessageType.toolActivity,
                ));
              }
              final result = await _toolRegistry!.execute(toolName, args);
              if (onToolActivity != null && result.displayText != null) {
                onToolActivity(ChatMessage(
                  text: result.displayText!,
                  isUser: false,
                  type: MessageType.toolActivity,
                ));
              }
              return result.result;
            }

            final reply = await _localModel.chat(
              messages.map((m) => {
                    'role': m['role'] as String,
                    'content': m['content'] as String,
                  }).toList(),
              systemPrompt: systemPrompt,
              temperature: 0.5,
              maxTokens: 512,
              toolDefinitions: _toolRegistry?.getToolDefinitions(),
              onToolCall: _toolRegistry != null ? onToolCall : null,
              maxToolRounds: 3,
            );
            final words = reply.split(' ');
            for (int i = 0; i < words.length; i++) {
              if (controller.isClosed) break;
              controller.add((i == 0 ? '' : ' ') + words[i]);
            }
            await _saveMemory(memory, userMessage, reply);
            _maybeEvolve(personaEvolution, history, userMessage, reply);
          } catch (e) {
            debugPrint('Local model failed: $e');
            try { await _localModel.unloadModel(); } catch (_) {}
            if (!controller.isClosed) {
              controller.add('Entschuldige, das lokale Modell hat ein Problem: $e');
            }
          }
        } else {
          if (!controller.isClosed) {
            controller.add('Bitte wähle einen KI-Anbieter in den Einstellungen oder lade ein lokales Modell herunter.');
          }
        }
      } catch (e) {
        debugPrint('streamResponse outer error: $e');
        if (!controller.isClosed) {
          controller.add('Es ist ein Fehler aufgetreten. Bitte versuche es erneut.');
        }
      } finally {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    }

    _run();
    return controller.stream;
  }

  Future<String> sendMessage({
    required String userMessage,
    required PersonaService persona,
    required MemoryService memory,
    required List<ChatMessage> history,
    PersonaEvolutionService? personaEvolution,
    ToolDisplayCallback? onToolActivity,
  }) async {
    final evolutionContext = personaEvolution?.buildEvolutionContext();
    var systemPrompt = await _buildSystemPrompt(persona, memory, userMessage,
        evolutionContext: evolutionContext);

    final chatHistory = history
        .where((m) => m.type == MessageType.text || m.type == MessageType.voice)
        .toList();
    final windowedHistory = chatHistory.length > 20
        ? chatHistory.sublist(chatHistory.length - 20)
        : chatHistory;
    final messages = windowedHistory
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final lastMsg = messages.isNotEmpty ? messages.last : null;
    final alreadyInHistory = lastMsg != null &&
        lastMsg['role'] == 'user' &&
        lastMsg['content'] == userMessage;
    if (!alreadyInHistory) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    if (_useCloud()) {
      // ── Cloud inference path (Ollama/OpenRouter) ──
      try {
        final cloud = _getCloudService();

        // Tool execution callback
        Future<String> onCloudToolCall(String toolName, Map<String, dynamic> args) async {
          debugPrint('sendMessage (cloud) executing tool: $toolName args=$args');
          if (onToolActivity != null) {
            onToolActivity(ChatMessage(
              text: '🔧 $toolName...',
              isUser: false,
              type: MessageType.toolActivity,
            ));
          }
          final result = await _toolRegistry!.execute(toolName, args);
          if (onToolActivity != null && result.displayText != null) {
            onToolActivity(ChatMessage(
              text: result.displayText!,
              isUser: false,
              type: MessageType.toolActivity,
            ));
          }
          return result.result;
        }

        final cloudMessages = messages.map((m) => {
          'role': m['role'] as String,
          'content': m['content'] as String,
        }).toList();

        if (_toolRegistry != null && _toolRegistry!.getToolDefinitions().isNotEmpty) {
          final chatResponse = await cloud.chatWithTools(
            systemPrompt: systemPrompt!,
            messages: cloudMessages.cast<Map<String, dynamic>>(),
            tools: _toolRegistry!.getToolDefinitions(),
            temperature: 0.3,
          );

          if (chatResponse.hasToolCalls) {
            final reply = await _executeCloudToolLoop(
              cloud: cloud,
              systemPrompt: systemPrompt!,
              messages: cloudMessages.cast<Map<String, dynamic>>(),
              chatResponse: chatResponse,
              onToolCall: onCloudToolCall,
              maxRounds: 3,
            );
            await _saveMemory(memory, userMessage, reply);
            _maybeEvolve(personaEvolution, history, userMessage, reply);
            return reply;
          } else {
            final reply = chatResponse.content;
            await _saveMemory(memory, userMessage, reply);
            _maybeEvolve(personaEvolution, history, userMessage, reply);
            return reply;
          }
        } else {
          final reply = await cloud.chat(
            systemPrompt: systemPrompt!,
            messages: cloudMessages.cast<Map<String, String>>(),
            temperature: 0.3,
          );
          await _saveMemory(memory, userMessage, reply);
          _maybeEvolve(personaEvolution, history, userMessage, reply);
          return reply;
        }
      } catch (e) {
        debugPrint('Cloud model failed: $e');
        return 'Entschuldige, die Cloud-Verbindung hat ein Problem: $e';
      }
    } else if (_useLocal()) {
      // ── Local inference path ──
      try {
        Future<String> onToolCall(String toolName, Map<String, dynamic> args) async {
          debugPrint('sendMessage executing tool: $toolName args=$args');
          if (onToolActivity != null) {
            onToolActivity(ChatMessage(
              text: '🔧 $toolName...',
              isUser: false,
              type: MessageType.toolActivity,
            ));
          }
          final result = await _toolRegistry!.execute(toolName, args);
          if (onToolActivity != null && result.displayText != null) {
            onToolActivity(ChatMessage(
              text: result.displayText!,
              isUser: false,
              type: MessageType.toolActivity,
            ));
          }
          return result.result;
        }

        final reply = await _localModel.chat(
          messages.map((m) => {
                'role': m['role'] as String,
                'content': m['content'] as String,
              }).toList(),
          systemPrompt: systemPrompt,
          temperature: 0.3,
          maxTokens: 512,
          toolDefinitions: _toolRegistry?.getToolDefinitions(),
          onToolCall: _toolRegistry != null ? onToolCall : null,
          maxToolRounds: 3,
        );
        await _saveMemory(memory, userMessage, reply);
        _maybeEvolve(personaEvolution, history, userMessage, reply);
        return reply;
      } catch (e) {
        debugPrint('Local model failed: $e');
        await _localModel.unloadModel();
        return 'Entschuldige, das lokale Modell hat ein Problem: $e';
      }
    }

    return 'Bitte wähle einen KI-Anbieter in den Einstellungen oder lade ein lokales Modell herunter.';
  }

  void _triggerEvolutionAndIntrospection(
    PersonaEvolutionService evolution,
    List<ChatMessage> history,
    String userMessage,
    String assistantReply,
  ) {
    // Run evolution in background (don't block chat)
    Future.microtask(() async {
      try {
        // Build mini-prompt for evolution from last 5 exchanges
        final miniHistory = history.length > 5
            ? history.sublist(history.length - 5)
            : history;
        final conversation = miniHistory.map((m) =>
            '${m.isUser ? "User" : "KI"}: ${m.text}').join('\n');
        
        final prompt = 'Analysiere dieses Gespräch und extrahiere:\n'
            '1. Neue Verhaltensregeln für die KI\n'
            '2. Beobachtungen zum User-Stil\n'
            '3. Wichtige Fakten über den User\n\n'
            'Gespräch:\n$conversation';

        // Try local model first for evolution, then cloud
        String result;
        if (_useLocal()) {
          result = await _localModel.chat(
            [{'role': 'user', 'content': prompt}],
            temperature: 0.3,
            maxTokens: 512,
          );
        } else if (_useCloud()) {
          result = await _getCloudService().chat(
            systemPrompt: 'Du bist ein Analyse-Assistent.',
            messages: [{'role': 'user', 'content': prompt}],
            temperature: 0.3,
          );
        } else {
          return; // No model available
        }
        
        // Parse and apply evolution results
        evolution.parseEvolutionResponse(result);
      } catch (e) {
        debugPrint('Evolution analysis error: $e');
      }
    });
  }

  /// Execute a tool-call loop for cloud LLM responses.
  /// When the cloud model returns tool calls, execute them and continue the conversation.
  Future<String> _executeCloudToolLoop({
    required OllamaCloudService cloud,
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    required ChatResponse chatResponse,
    required Future<String> Function(String, Map<String, dynamic>) onToolCall,
    required int maxRounds,
  }) async {
    var currentMessages = List<Map<String, dynamic>>.from(messages);
    var currentResponse = chatResponse;
    int rounds = 0;

    while (currentResponse.hasToolCalls && rounds < maxRounds) {
      // Add assistant message with tool calls to history
      currentMessages.add(currentResponse.toolCalls.first.toAssistantMessage());

      for (final tc in currentResponse.toolCalls) {
        debugPrint('Cloud tool call: ${tc.name} args=${tc.arguments}');
        String result;
        try {
          result = await onToolCall(tc.name, tc.arguments);
        } catch (e) {
          result = 'Fehler: $e';
        }
        // Trim result to reasonable length
        final trimmedResult = result.length > 2000 ? '${result.substring(0, 2000)}...' : result;
        // Add tool result message
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': trimmedResult,
        });
      }

      // Get next response from the model
      currentResponse = await cloud.chatWithTools(
        systemPrompt: systemPrompt,
        messages: currentMessages,
        tools: _toolRegistry?.getToolDefinitions(),
        temperature: 0.5,
      );
      rounds++;
    }

    return currentResponse.content.isNotEmpty
        ? currentResponse.content
        : 'Tool-Aufruf ausgeführt.';
  }

  /// Save memory entries (user + assistant) and promote if important.
  Future<void> _saveMemory(MemoryService memory, String userMessage, String reply) async {
    await Future.wait([
      memory.addShortTerm(userMessage, source: 'user'),
      memory.addShortTerm(reply, source: 'assistant'),
    ]);
    try {
      await memory.promoteIfImportant(userMessage, 'auto-assess: content from conversation');
      await memory.promoteIfImportant(reply, 'auto-assess: response from conversation');
    } catch (e) {
      debugPrint('Memory promotion error: $e');
    }
  }

  /// Trigger persona evolution if interval reached.
  void _maybeEvolve(PersonaEvolutionService? personaEvolution, List<ChatMessage> history, String userMessage, String reply) {
    _messageCount++;
    if (personaEvolution != null && _messageCount % evolutionInterval == 0) {
      _triggerEvolutionAndIntrospection(personaEvolution, history, userMessage, reply);
    }
  }

  Future<String> _buildSystemPrompt(
      PersonaService persona, MemoryService memory, String query,
      {String? evolutionContext}) async {
    final base = persona.buildSystemPrompt(evolutionContext: evolutionContext);
    final parts = <String>[base];

    // KI-Selbstbild — nur Essenz, nicht alles
    final selfIdentity = _selfIdentity;
    if (selfIdentity != null && selfIdentity.essence.isNotEmpty) {
      parts.add('Du bist: ${selfIdentity.essence}');
    }

    // Core memories — max 3 wichtigste
    final coreContext = memory.buildCoreContext();
    if (coreContext.isNotEmpty) {
      parts.add(coreContext);
    }

    // Buddy Capabilities — Was die KI alles kann
    final caps = _buddyCapabilities?.capabilities;
    if (caps != null && caps.isNotEmpty) {
      parts.add(caps);
    }

    // Relevante Memories — limitiert auf 3 pro Tier
    final relevant = await memory.retrieveRelevant(query, limitPerTier: 3);
    if (relevant['longTerm']!.isNotEmpty) {
      final buf = StringBuffer('\n=== Erinnerungen ===\n');
      for (final m in relevant['longTerm']!) {
        buf.writeln('- ${m.content}');
      }
      parts.add(buf.toString());
    }
    if (relevant['shortTerm']!.isNotEmpty) {
      final buf = StringBuffer('\n=== Kontext ===\n');
      for (final m in relevant['shortTerm']!) {
        buf.writeln('- ${m.content}');
      }
      parts.add(buf.toString());
    }

    // Tool-Hinweis — kompakt
    parts.add('\n🧠 Tools: update_self_identity, save_memory, search_memories — nutze sie aktiv.');

    // Standort — nur wenn wirklich da
    final locService = _locationService;
    if (locService != null) {
      try {
        final locContext = await locService.buildContextString();
        if (locContext.isNotEmpty) {
          parts.add('\n📍 $locContext');
        }
      } catch (e) {
        debugPrint('Location context error: $e');
      }
    }

    return parts.join('\n').trim();
  }
}
