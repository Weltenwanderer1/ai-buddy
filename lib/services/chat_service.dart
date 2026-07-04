import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/llm_provider.dart';
import '../services/ollama_cloud_provider.dart';
import '../services/ollama_cloud_service.dart';
import '../services/anthropic_provider.dart';
import '../services/anthropic_service.dart';
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
  final AnthropicService? _anthropicService;
  final SecureConfigService? _configService;
  final ToolRegistry? _toolRegistry;
  final SelfIdentityService? _selfIdentity;
  final LocationService? _locationService;
  final BuddyCapabilitiesService? _buddyCapabilities;
  int _messageCount = 0;
  static const int evolutionInterval = 10;

  ChatService({OllamaCloudService? cloudService, AnthropicService? anthropicService, SecureConfigService? configService, ToolRegistry? toolRegistry, SelfIdentityService? selfIdentity, LocationService? locationService, BuddyCapabilitiesService? buddyCapabilities})
      : _cloudService = cloudService,
        _anthropicService = anthropicService,
        _configService = configService,
        _toolRegistry = toolRegistry,
        _selfIdentity = selfIdentity,
        _locationService = locationService,
        _buddyCapabilities = buddyCapabilities;

  /// Resolve the active LLM provider based on config.
  /// Supports: ollama, openrouter, openai (via OllamaCloudService),
  /// and anthropic (via AnthropicService).
  LlmProvider? _resolveProvider() {
    final config = _configService;
    final provider = config?.llmProvider ?? 'ollama';

    // Anthropic has its own service + provider (Messages API format)
    if (provider == 'anthropic') {
      if (_anthropicService != null && config != null) {
        _anthropicService!.updateConfig(
          baseUrl: config.anthropicBaseUrl,
          apiKey: config.anthropicApiKey,
          defaultModel: config.anthropicModel,
          fallbackModel: config.anthropicFallbackModel,
        );
        return AnthropicProvider(_anthropicService!);
      }
      return null;
    }

    // ollama, openrouter, openai — all use the OpenAI-compatible endpoint
    // via OllamaCloudService
    if (_cloudService != null && config != null) {
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
    Map<String, dynamic>? fileMetadata,
  }) {
    final controller = StreamController<String>();

    Future<void> run() async {
      try {
        final evolutionContext = personaEvolution?.buildEvolutionContext();
        var systemPrompt = await _buildSystemPrompt(
          persona, memory, userMessage,
          evolutionContext: evolutionContext,
        );

        final messages = _buildMessagesFromHistory(
          history.where((m) => m.type == MessageType.text || m.type == MessageType.voice || m.type == MessageType.system).toList(),
          userMessageText: userMessage,
          userFileMetadata: fileMetadata,
        );

        final provider = _resolveProvider();
        if (provider == null) {
          if (!controller.isClosed) {
            controller.add('Bitte wähle einen KI-Anbieter in den Einstellungen (Ollama, OpenRouter, OpenAI oder Anthropic).');
          }
          if (!controller.isClosed) controller.close();
          return;
        }

        // Tool-Callbacks für den Streaming-Pfad (analog zu sendMessage)
        Future<String> Function(String, Map<String, dynamic>)? onToolCall;
        final registry = _toolRegistry;
        if (registry != null && registry.getToolDefinitions().isNotEmpty) {
          onToolCall = (String toolName, Map<String, dynamic> args) async {
            final result = await registry.execute(toolName, args);
            return result.result;
          };
        }

        try {
          final stream = provider.streamChat(
            systemPrompt: systemPrompt,
            messages: messages.cast<Map<String, dynamic>>(),
            temperature: 0.5,
            toolDefinitions: registry?.getToolDefinitions(),
            onToolCall: onToolCall,
            maxToolRounds: 5,
            onToolActivity: (toolName) {
              // '🔧'-Marker: signalisiert der UI laufende Tool-Ausführung
              if (!controller.isClosed) controller.add('🔧');
              onToolActivity?.call(ChatMessage(
                text: '🔧 $toolName...',
                isUser: false,
                type: MessageType.toolActivity,
              ));
            },
          );

          final replyBuffer = StringBuffer();
          await for (final chunk in stream) {
            if (controller.isClosed) break;
            controller.add(chunk);
            if (chunk != '🔧') replyBuffer.write(chunk);
          }

          // Auch der Streaming-Pfad muss ins Gedächtnis schreiben — sonst
          // hinterlassen Streaming-Antworten weder Kurzzeit-Memory noch
          // Auto-Extraktion/Evolution (sendMessage macht beides).
          final fullReply = replyBuffer.toString();
          if (fullReply.isNotEmpty) {
            _saveMemory(memory, userMessage, fullReply);
            _maybeEvolve(personaEvolution, history, userMessage, fullReply, memory);
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
    Map<String, dynamic>? fileMetadata,
  }) async {
    final evolutionContext = personaEvolution?.buildEvolutionContext();
    var systemPrompt = await _buildSystemPrompt(persona, memory, userMessage,
        evolutionContext: evolutionContext);

    final messages = _buildMessagesFromHistory(
      history.where((m) => m.type == MessageType.text || m.type == MessageType.voice || m.type == MessageType.system).toList(),
      userMessageText: userMessage,
      userFileMetadata: fileMetadata,
    );

    final provider = _resolveProvider();
    if (provider == null) {
      return ChatResult('Bitte wähle einen KI-Anbieter in den Einstellungen (Ollama, OpenRouter, OpenAI oder Anthropic).');
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
      _maybeEvolve(personaEvolution, history, userMessage, reply, memory);
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
    MemoryService? memory,
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

        final prompt = 'Analysiere dieses Gespräch und extrahiere Erkenntnisse.\n\n'
            'Gespräch:\n$conversation\n\n'
            'Antworte AUSSCHLIESSLICH als JSON:\n'
            '{\n'
            '  "traits": ["Vollstaendige Saetze die Verhaltensregeln beschreiben"],\n'
            '  "user_facts": ["Wichtige Fakten ueber den User als vollstaendige Saetze"],\n'
            '  "avoid_topics": ["Themen die vermieden werden sollten"],\n'
            '  "preferred_style": ["Bevorzugter Kommunikationsstil"]\n'
            '}\n\n'
            'Leere Arrays wenn nichts relevant. JSON:';

        // Use whichever provider is available for evolution analysis
        String result;
        final provider = _resolveProvider();
        if (provider != null) {
          result = await provider.chat(
            systemPrompt: 'Du bist ein JSON-Generator. Antworte nur mit gültigem JSON.',
            messages: [{'role': 'user', 'content': prompt}],
            temperature: 0.3,
          );
        } else {
          return; // No model available
        }

        // Parse structured JSON response
        _parseStructuredEvolution(result, evolution, memory);

        // Also trigger self-identity introspection
        final selfIdentity = _selfIdentity;
        if (selfIdentity != null) {
          final changes = await selfIdentity.introspect(conversation, provider);
          if (changes != null) {
            debugPrint('SelfIdentity: introspection updated — $changes');
          }
        }
      } catch (e) {
        debugPrint('Evolution analysis error: $e');
      }
    });
  }

  /// Parse structured JSON evolution response and apply to evolution service.
  void _parseStructuredEvolution(String response, PersonaEvolutionService evolution, MemoryService? memory) {
    try {
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return;
      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Add traits as full sentences
      final traits = data['traits'] as List? ?? [];
      for (final trait in traits) {
        final s = trait.toString().trim();
        if (s.length >= 10) {
          evolution.addTrait(s);
        }
      }

      // Save user facts as long-term memories
      final facts = data['user_facts'] as List? ?? [];
      for (final fact in facts) {
        final s = fact.toString().trim();
        if (s.length >= 10) {
          memory?.addLongTerm(s, source: 'evolution');
        }
      }

      // Avoid topics
      final avoid = data['avoid_topics'] as List? ?? [];
      for (final topic in avoid) {
        final s = topic.toString().trim();
        if (s.isNotEmpty) {
          evolution.addAvoidTopic(s);
        }
      }

      // Preferred style
      final style = data['preferred_style'] as List? ?? [];
      for (final s in style) {
        final str = s.toString().trim();
        if (str.isNotEmpty) {
          evolution.addPreferredStyle(str);
        }
      }
    } catch (e) {
      debugPrint('Evolution parse error: $e, falling back to line parser');
      evolution.parseEvolutionResponse(response);
    }
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

  /// Convert chat history to LLM message format.
  /// Handles vision (image) messages by building multi-content arrays.
  List<Map<String, dynamic>> _buildMessagesFromHistory(
    List<ChatMessage> history, {
    String? userMessageText,
    Map<String, dynamic>? userFileMetadata,
  }) {
    // Nur das JÜNGSTE Bild geht als Vision-Content mit — sonst wächst jede
    // Anfrage um sämtliche je gesendeten Bilder (~0,5-1 MB Base64 pro Bild).
    int lastImageIdx = -1;
    for (var i = 0; i < history.length; i++) {
      final b64 = history[i].metadata?['image_bytes_base64'] as String?;
      if (history[i].isUser && b64 != null && b64.isNotEmpty) lastImageIdx = i;
    }

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < history.length; i++) {
      final m = history[i];
      if (m.type != MessageType.text &&
          m.type != MessageType.voice &&
          m.type != MessageType.system) {
        continue;
      }
      final role = m.isUser ? 'user' : 'assistant';
      final imageB64 = m.metadata?['image_bytes_base64'] as String?;
      final hasImage = imageB64 != null && imageB64.isNotEmpty;
      if (hasImage && i == lastImageIdx) {
        // Vision message: content as array with text + image_url
        result.add({
          'role': role,
          'content': [
            {'type': 'text', 'text': m.text},
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageB64'}},
          ],
        });
      } else if (hasImage) {
        // Ältere Bilder nur als Text-Hinweis mitgeben
        result.add({'role': role, 'content': '${m.text} [Bild gesendet]'});
      } else {
        result.add({'role': role, 'content': m.text});
      }
    }

    // Append current user message if not already present.
    // Der Vergleich muss auch Vision-Nachrichten (List-Content) erkennen —
    // sonst wird die aktuelle Bild-Nachricht doppelt angehängt.
    if (userMessageText != null) {
      final last = result.isNotEmpty ? result.last : null;
      String? lastUserText;
      if (last != null && last['role'] == 'user') {
        final c = last['content'];
        if (c is String) {
          lastUserText = c;
        } else if (c is List) {
          for (final part in c) {
            if (part is Map && part['type'] == 'text') {
              lastUserText = part['text'] as String?;
              break;
            }
          }
        }
      }
      final alreadyInHistory = lastUserText == userMessageText;
      if (!alreadyInHistory) {
        final imageB64 = userFileMetadata?['image_bytes_base64'] as String?;
        if (imageB64 != null && imageB64.isNotEmpty) {
          result.add({
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userMessageText},
              {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageB64'}},
            ],
          });
        } else {
          result.add({'role': 'user', 'content': userMessageText});
        }
      }
    }

    return result;
  }

  /// Trigger persona evolution if interval reached.
  void _maybeEvolve(PersonaEvolutionService? personaEvolution, List<ChatMessage> history, String userMessage, String reply, MemoryService? memory) {
    _messageCount++;
    if (personaEvolution != null && _messageCount % evolutionInterval == 0) {
      _triggerEvolutionAndIntrospection(personaEvolution, history, userMessage, reply, memory);
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
    parts.add('Speichere NUR vollstaendige Saetze mit Kontext: "Der Nutzer heisst X und wohnt in Y" — NIEMALS nur "X".');

    // Proaktivitäts-Regel: Eigeninitiative statt Nachfragen
    parts.add('Zeige Eigeninitiative: Erkennst du einen nützlichen Timer, Erinnerung oder Vorschlag, HANDELE direkt. "Ich stelle einen Timer..." statt "Soll ich...". Bei kritischen Aktionen (Nachrichten, Löschen, Einkäufe) frag VORHER nach.');

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
