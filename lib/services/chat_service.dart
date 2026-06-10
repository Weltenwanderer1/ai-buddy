import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/llm_provider.dart';
import '../services/ollama_cloud_provider.dart';
import '../services/ollama_cloud_service.dart';
import '../services/secure_config_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/self_identity_service.dart';
import '../services/contextual_memory_extractor.dart';
import '../services/location_service.dart';
import '../services/buddy_capabilities_service.dart';
import '../tools/tool_registry.dart';

typedef ToolDisplayCallback = void Function(ChatMessage toolMessage);

/// Result from sendMessage — carries the reply text and optional metadata
/// from tool calls (e.g. route data for navigation, location coordinates).
class ChatResult {
  final String text;
  final Map<String, dynamic>? metadata;
  ChatResult(this.text, {this.metadata});
}

class ChatService {
  final OllamaCloudService? _cloudService;
  final SecureConfigService? _configService;
  final ToolRegistry? _toolRegistry;
  final SelfIdentityService? _selfIdentity;
  final LocationService? _locationService;
  final BuddyCapabilitiesService? _buddyCapabilities;
  int _messageCount = 0;
  static const int evolutionInterval = 10;

  ChatService({OllamaCloudService? cloudService, SecureConfigService? configService, ToolRegistry? toolRegistry, SelfIdentityService? selfIdentity, LocationService? locationService, BuddyCapabilitiesService? buddyCapabilities})
      : _cloudService = cloudService,
        _configService = configService,
        _toolRegistry = toolRegistry,
        _selfIdentity = selfIdentity,
        _locationService = locationService,
        _buddyCapabilities = buddyCapabilities;

  /// Resolve the active LLM provider based on config.
  /// Only cloud providers (ollama/openrouter).
  LlmProvider? _resolveProvider() {
    final config = _configService;
    final provider = config?.llmProvider ?? 'ollama';

    if ((provider == 'ollama' || provider == 'openrouter') && _cloudService != null && config != null) {
      // Update cloud config from SecureConfigService
      _cloudService!.updateConfig(
        baseUrl: config.activeBaseUrl,
        apiKey: config.activeApiKey,
        defaultModel: config.activeModel,
        fallbackModel: config.activeFallbackModel,
      );
      return OllamaCloudProvider(_cloudService!);
    }

    return null;
  }

  Stream<String> streamResponse({
    required String userMessage,
    required PersonaService persona,
    required MemoryService memory,
    required List<ChatMessage> history,
    PersonaEvolutionService? personaEvolution,
    ToolDisplayCallback? onToolActivity,
  }) {
    final controller = StreamController<String>();

    Future<void> run() async {
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

        final provider = _resolveProvider();
        if (provider == null) {
          if (!controller.isClosed) {
            controller.add('Bitte wähle einen KI-Anbieter in den Einstellungen (Ollama oder OpenRouter).');
          }
          if (!controller.isClosed) controller.close();
          return;
        }

        // Streaming currently only supports text-only (no tools)
        try {
          final stream = provider.streamChat(
            systemPrompt: systemPrompt,
            messages: messages.cast<Map<String, dynamic>>(),
            temperature: 0.5,
          );

          await for (final chunk in stream) {
            if (controller.isClosed) break;
            controller.add(chunk);
          }
        } catch (e) {
          debugPrint('Streaming failed: $e');
          if (!controller.isClosed) {
            final short = e.toString();
            final msg = short.length > 120 ? '${short.substring(0, 120)}...' : short;
            controller.add('Verbindungsproblem: $msg');
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

    run();
    return controller.stream;
  }

  Future<ChatResult> sendMessage({
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

    final provider = _resolveProvider();
    if (provider == null) {
      return ChatResult('Bitte wähle einen KI-Anbieter in den Einstellungen (Ollama oder OpenRouter).');
    }

    try {
      // Build tool execution callbacks — capture extraData from last tool result
      Map<String, dynamic>? lastToolExtraData;
      Future<String> Function(String, Map<String, dynamic>)? onToolCall;
      void Function(String)? onToolActivityWrapper;

      final registry = _toolRegistry;
      if (registry != null && registry.getToolDefinitions().isNotEmpty) {
        onToolCall = (String toolName, Map<String, dynamic> args) async {
          debugPrint('ChatService tool: $toolName');
          final result = await registry.execute(toolName, args);
          if (result.extraData != null && result.extraData!.isNotEmpty) {
            lastToolExtraData = result.extraData;
          }
          return result.result;
        };

        if (onToolActivity != null) {
          onToolActivityWrapper = (String toolName) {
            onToolActivity(ChatMessage(
              text: '🔧 $toolName...',
              isUser: false,
              type: MessageType.toolActivity,
            ));
          };
        }
      }

      final reply = await provider.chat(
        systemPrompt: systemPrompt,
        messages: messages.cast<Map<String, dynamic>>(),
        temperature: 0.3,
        toolDefinitions: _toolRegistry?.getToolDefinitions(),
        onToolCall: onToolCall,
        onToolActivity: onToolActivityWrapper,
        maxToolRounds: 5,
      );

      _saveMemory(memory, userMessage, reply);
      _maybeEvolve(personaEvolution, history, userMessage, reply);
      return ChatResult(reply, metadata: lastToolExtraData);
    } catch (e) {
      debugPrint('Provider failed: $e');
      final errStr = e.toString();
      final truncated = errStr.length > 100 ? '${errStr.substring(0, 100)}...' : errStr;
      return ChatResult('KI-Problem: $truncated');
    }
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

        // Use whichever provider is available for evolution analysis
        String result;
        final provider = _resolveProvider();
        if (provider != null) {
          result = await provider.chat(
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

  /// Save memory entries with auto-extraction + promotion pipeline.
  /// Runs contextual extraction on the combined turn, stores in
  /// short-term, and promotes important ones to long-term automatically.
  void _saveMemory(MemoryService memory, String userMessage, String reply) {
    // Store both messages in short-term (preserves conversation flow).
    // Intentionally not awaited (don't block the chat turn), but errors
    // must be handled — an unhandled async error would crash the zone.
    Future.wait([
      memory.addShortTerm(userMessage, source: 'user'),
      memory.addShortTerm(reply, source: 'assistant'),
    ]).catchError((Object e) {
      debugPrint('Memory save error: $e');
      return <void>[];
    });

    // Auto-extract memories from the conversation turn
    // Runs locally — no extra LLM call, instant
    Future.microtask(() async {
      try {
        final extractor = ContextualMemoryExtractor();
        final extracted = extractor.extract(userMessage, reply);
        if (extracted.isEmpty) return;

        for (final mem in extracted) {
          if (mem.isCore) {
            // Highest importance → core identity
            await memory.addCore(mem.content, source: 'auto-extracted', metadata: {
              'category': mem.category.name,
              'tier': mem.tier,
            });
          } else if (mem.isImportant) {
            // Standard importance → long-term memory
            await memory.addLongTerm(mem.content, source: 'auto-extracted', metadata: {
              'category': mem.category.name,
              'tier': mem.tier,
            });
          }
          // Tier < 6 → stays in short-term (will expire via TTL)
        }

        debugPrint('Auto-extracted ${extracted.length} memories from turn');
      } catch (e) {
        debugPrint('Auto-extraction error: $e');
      }
    });
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
      final buf = StringBuffer('\nErinnerungen:\n');
      for (final m in relevant['longTerm']!) {
        buf.writeln('- ${m.content}');
      }
      parts.add(buf.toString());
    }
    if (relevant['shortTerm']!.isNotEmpty) {
      final buf = StringBuffer('\nKontext:\n');
      for (final m in relevant['shortTerm']!) {
        buf.writeln('- ${m.content}');
      }
      parts.add(buf.toString());
    }

    // Tool-Hinweis — kompakt
    parts.add('\nNutze update_self_identity, save_memory, search_memories aktiv.');

    // Gelernte Fehler-Tipps fuer Tools (durch ToolRegistry)
    final toolHints = _toolRegistry?.getToolHints() ?? '';
    if (toolHints.isNotEmpty) {
      parts.add(toolHints);
    }

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
