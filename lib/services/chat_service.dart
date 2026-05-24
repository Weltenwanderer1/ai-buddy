import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/ollama_cloud_service.dart';
import '../services/local_model_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/self_identity_service.dart';
import '../services/location_service.dart';
import '../services/buddy_capabilities_service.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_result.dart';
import 'tool_call_parser.dart';

typedef ToolDisplayCallback = void Function(ChatMessage toolMessage);
typedef StreamingCallback = void Function(String partialText);

class ChatService {
  final OllamaCloudService _llm;
  final ToolRegistry? _toolRegistry;
  final SelfIdentityService? _selfIdentity;
  final LocationService? _locationService;
  final BuddyCapabilitiesService? _buddyCapabilities;
  final int maxToolRounds;
  final LocalModelService? _localModel;
  int _messageCount = 0;
  static const int evolutionInterval = 10;

  ChatService(this._llm, {ToolRegistry? toolRegistry, SelfIdentityService? selfIdentity, LocationService? locationService, BuddyCapabilitiesService? buddyCapabilities, LocalModelService? localModel, this.maxToolRounds = 5})
      : _toolRegistry = toolRegistry,
        _selfIdentity = selfIdentity,
        _locationService = locationService,
        _buddyCapabilities = buddyCapabilities,
        _localModel = localModel;

  /// Cached RegExps for _pickModel (avoid recompiling on every call).
  static final RegExp _cmdPrefixRegex = RegExp(
    r'^(oeffne|starte|mach|zeig|geh|navigier|fahr|bring|stell|timer|wecker|erinner|send|schick|schreib)',
    caseSensitive: false,
  );
  static final RegExp _chitchatRegex = RegExp(
    r'^(hi|hey|hallo|moin|servus|guten|nabend|danke|ok|okay|ja|nein|gut|super|toll|geil|cool|wie geht|was geht|und sonst|na du|machst du|was machst)',
    caseSensitive: false,
  );
  static final RegExp _factualQuestionRegex = RegExp(
    r'(wie|wo|wann|wer|was ist|welche|wieviel|wie viele)',
    caseSensitive: false,
  );

  /// Known app names for fallback matching in preload.
  static const _knownAppNames = [
    'spotify',
    'whatsapp',
    'telegram',
    'youtube',
    'netflix',
    'instagram',
    'tiktok',
    'discord',
    'signal',
    'threema',
    'firefox',
    'chrome',
    'browser',
    'maps',
    'gmail',
    'email',
    'kamera',
    'camera',
    'fotos',
    'photos',
    'einstellungen',
    'settings',
    'kalender',
    'calendar',
    'uhr',
    'clock',
    'rechner',
    'calculator',
    'notizen',
    'keep',
    'wetter',
    'weather',
    'amazon',
    'ebay',
    'paypal',
    'linkedin',
    'pinterest',
    'snapchat',
    'twitch',
    'prime',
    'disney',
    'zoom',
    'teams',
    'outlook',
    'uber',
    'wikipedia',
    'vlc',
    'shazam',
    'soundcloud',
    'airbnb',
    'booking',
    'reddit',
    'twitter',
    'x',
  ];

  /// Classify the user query to pick the right model: flash for simple, pro for complex.
  /// Flash (~1s response) for: greetings, simple questions, commands.
  /// Pro (~3-5s) for: analysis, explanations, writing, complex reasoning.
  String _pickModel(String userMessage, bool hasTools) {
    final msg = userMessage.toLowerCase().trim();

    // Commands that preload handles → always flash
    if (hasTools && _cmdPrefixRegex.hasMatch(msg)) {
      return _llm.fallbackModel;
    }

    // Simple chitchat → flash
    if (_chitchatRegex.hasMatch(msg)) {
      return _llm.fallbackModel;
    }

    // Short factual questions → flash
    if (msg.length < 30 && _factualQuestionRegex.hasMatch(msg)) {
      return _llm.fallbackModel;
    }

    // Default: use pro for anything that needs reasoning
    return _llm.defaultModel;
  }

  Stream<String> streamResponse({
    required String userMessage,
    required PersonaService persona,
    required MemoryService memory,
    required List<ChatMessage> history,
    PersonaEvolutionService? personaEvolution,
    ToolDisplayCallback? onToolActivity,
  }) async* {
    final evolutionContext = personaEvolution?.buildEvolutionContext();
    var systemPrompt = await _buildSystemPrompt(persona, memory, userMessage,
        evolutionContext: evolutionContext);

    // Tool execution is model-first. Regex extraction is only a fallback after
    // the model had a chance to emit a structured tool call.
    final hasTools =
        _toolRegistry != null && _toolRegistry!.toolNames.isNotEmpty;

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

    // Bugfix: don't double-send user message if already in history
    final lastMsg = messages.isNotEmpty ? messages.last : null;
    final alreadyInHistory = lastMsg != null &&
        lastMsg['role'] == 'user' &&
        lastMsg['content'] == userMessage;
    if (!alreadyInHistory) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    if (hasTools) {
      final pickedModel = _pickModel(userMessage, true);
      // Signal that tools are being executed (prevents UI from showing "thinking" forever)
      yield '🔧';
      final reply = await _chatWithToolLoop(
        systemPrompt: _withToolInstructions(systemPrompt, null),
        messages: messages,
        tools: _toolRegistry!.getToolDefinitions(),
        persona: persona,
        memory: memory,
        personaEvolution: personaEvolution,
        userMessage: userMessage,
        onToolActivity: onToolActivity,
        model: pickedModel,
      );
      if (reply.isNotEmpty) {
        // Chunk the reply into words for streaming feel
        final words = reply.split(' ');
        for (int i = 0; i < words.length; i++) {
          yield (i == 0 ? '' : ' ') + words[i];
        }
      }
      return;
    }

    final pickedModel = _pickModel(userMessage, false);
    final typedMessages = messages
        .map((m) =>
            {'role': (m['role']) ?? 'user', 'content': (m['content']) ?? ''})
        .toList();

    final stream = _llm.chatStream(
        systemPrompt: systemPrompt,
        messages: typedMessages,
        model: pickedModel);
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(chunk);
      yield chunk;
    }

    final fullReply = buffer.toString();
    if (fullReply.isNotEmpty) {
      await Future.wait([
        memory.addShortTerm(userMessage, source: 'user'),
        memory.addShortTerm(fullReply, source: 'assistant'),
      ]);
      // Auto-promote: check if conversation content is worth remembering long-term
      try {
        await memory.promoteIfImportant(userMessage, 'auto-assess: content from conversation');
        await memory.promoteIfImportant(fullReply, 'auto-assess: response from conversation');
      } catch (e) {
        debugPrint('Memory promotion error: $e');
      }
      _messageCount++;
      if (personaEvolution != null && _messageCount % evolutionInterval == 0) {
        _triggerEvolutionAndIntrospection(personaEvolution, history, userMessage, fullReply);
      }
    }
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

    // Bugfix: don't double-send
    final lastMsg = messages.isNotEmpty ? messages.last : null;
    final alreadyInHistory = lastMsg != null &&
        lastMsg['role'] == 'user' &&
        lastMsg['content'] == userMessage;
    if (!alreadyInHistory) {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final hasTools =
        _toolRegistry != null && _toolRegistry!.toolNames.isNotEmpty;
    final tools = hasTools ? _toolRegistry!.getToolDefinitions() : null;

    if (hasTools) {
      systemPrompt = _withToolInstructions(systemPrompt, null);
    }

    if (hasTools) {
      final pickedModel = _pickModel(userMessage, true);
      return await _chatWithToolLoop(
        systemPrompt: systemPrompt,
        messages: messages,
        tools: tools!,
        persona: persona,
        memory: memory,
        personaEvolution: personaEvolution,
        userMessage: userMessage,
        onToolActivity: onToolActivity,
        model: pickedModel,
      );
    } else {
      // Check if local model is enabled and available
      if (_localModel != null && _localModel!.useLocalModel && _localModel!.isModelAvailable) {
        final reply = await _localModel!.chat(
          messages.map((m) => {
                'role': m['role'] as String,
                'content': m['content'] as String,
              }).toList(),
          temperature: 0.3,
        );
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
        _messageCount++;
        if (personaEvolution != null && _messageCount % evolutionInterval == 0) {
          _triggerEvolutionAndIntrospection(personaEvolution, history, userMessage, reply);
        }
        return reply;
      }

      final pickedModel = _pickModel(userMessage, false);
      final reply = await _llm.chat(
        systemPrompt: systemPrompt,
        messages: messages
            .map((m) => {
                  'role': m['role'] as String,
                  'content': m['content'] as String,
                })
            .toList(),
        model: pickedModel,
      );
      await Future.wait([
        memory.addShortTerm(userMessage, source: 'user'),
        memory.addShortTerm(reply, source: 'assistant'),
      ]);
      // Auto-promote: check if conversation content is worth remembering long-term
      try {
        await memory.promoteIfImportant(userMessage, 'auto-assess: content from conversation');
        await memory.promoteIfImportant(reply, 'auto-assess: response from conversation');
      } catch (e) {
        debugPrint('Memory promotion error: $e');
      }
      _messageCount++;
      if (personaEvolution != null && _messageCount % evolutionInterval == 0) {
        _triggerEvolutionAndIntrospection(personaEvolution, history, userMessage, reply);
      }
      return reply;
    }
  }

  String _withToolInstructions(String basePrompt, String? preloadedLiveData) {
    final toolNames = _toolRegistry?.toolNames.join(', ') ?? '';
    final buffer = StringBuffer(basePrompt);
    buffer.write('\n\nTools: $toolNames. Nutze sie für echte Aktionen.');
    if (preloadedLiveData != null && preloadedLiveData.trim().isNotEmpty) {
      buffer.write('\nDaten: ${preloadedLiveData.trim()}');
    }
    return buffer.toString();
  }

  Future<String> _chatWithToolLoop({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required PersonaService persona,
    required MemoryService memory,
    PersonaEvolutionService? personaEvolution,
    required String userMessage,
    ToolDisplayCallback? onToolActivity,
    String? model,
  }) async {
    List<Map<String, dynamic>> conversationMessages = List.from(messages);

    for (int round = 0; round < maxToolRounds; round++) {
      ChatResponse response;
      try {
        response = await _llm.chatWithTools(
          systemPrompt: systemPrompt,
          messages: conversationMessages,
          tools: tools,
          model: model,
        );
      } catch (e) {
        debugPrint('Tool loop: LLM call failed at round $round: $e');
        // Return a user-friendly error instead of throwing
        final errStr = e.toString();
        String userMsg;
        if (errStr.contains('SocketException') || errStr.contains('Failed host lookup') || errStr.contains('Connection refused')) {
          userMsg = 'Verbindung zum Server fehlgeschlagen. Bitte prüfe deine Internetverbindung und die API-URL in den Einstellungen.';
        } else if (errStr.contains('TimeoutException') || errStr.contains('timed out')) {
          userMsg = 'Der Server braucht zu lange zu antworten. Bitte versuche es in einem Moment erneut.';
        } else {
          userMsg = 'Es ist ein Fehler bei der Kommunikation mit dem Sprachmodell aufgetreten. Bitte versuche es erneut. (Fehler: ${errStr.length > 120 ? '${errStr.substring(0, 120)}...' : errStr})';
        }
        return '$userMsg (URL: ${_llm.chatCompletionsUrl})';
      }

      var effectiveToolCalls = response.hasToolCalls
          ? response.toolCalls
          : _parseInlineToolCalls(response.content);
      effectiveToolCalls = _normalizeToolCalls(effectiveToolCalls);

      // Filter out LLM "apology" responses — sometimes the model outputs
      // "Entschuldige, hier ist was schiefgegangen" or similar instead of making a tool call.
      // If we got no tool calls and the content looks like an error/apology, retry once.
      if (effectiveToolCalls.isEmpty && _isApologyResponse(response.content)) {
        debugPrint(
            'Tool loop: LLM returned apology instead of tool call, retrying with explicit hint');
        conversationMessages.add({
          'role': 'user',
          'content':
              'Bitte nutze das passende Tool (open_app, open_navigation, etc.) anstatt zu entschuldigen. Was ich brauche: $userMessage'
        });
        continue;
      }

      if (effectiveToolCalls.isEmpty) {
        final fallbackCalls = _fallbackToolCalls(userMessage);
        if (fallbackCalls.isNotEmpty) {
          debugPrint(
              'Tool loop: using regex fallback after model produced no tool call');
          effectiveToolCalls = fallbackCalls;
          conversationMessages.add({
            'role': 'assistant',
            'content': response.content.isEmpty
                ? 'Ich nutze das passende Tool.'
                : ToolCallParser.stripFunctionCallTags(response.content),
          });
        } else {
          final reply = ToolCallParser.stripFunctionCallTags(response.content);
          if (reply.trim().isEmpty) {
            // LLM returned empty content with no tool calls — try once more
            if (round < maxToolRounds - 1) continue;
            return 'Ich konnte keine Antwort generieren. Bitte versuche es erneut.';
          }
          await Future.wait([
            memory.addShortTerm(userMessage, source: 'user'),
            memory.addShortTerm(reply, source: 'assistant'),
          ]);
          // Auto-promote: check if conversation content is worth remembering long-term
          try {
            await memory.promoteIfImportant(userMessage, 'auto-assess: content from conversation');
            await memory.promoteIfImportant(reply, 'auto-assess: response from conversation');
          } catch (e) {
            debugPrint('Memory promotion error: $e');
          }
          _messageCount++;
          if (personaEvolution != null &&
              _messageCount % evolutionInterval == 0) {
            _triggerEvolutionAndIntrospection(personaEvolution, [], userMessage, reply);
          }
          return reply;
        }
      }

      if (response.hasToolCalls) {
        conversationMessages.add(effectiveToolCalls.first.toAssistantMessage());
        if (effectiveToolCalls.length > 1) {
          conversationMessages.removeLast();
          conversationMessages.add({
            'role': 'assistant',
            'content': response.content,
            'tool_calls': effectiveToolCalls
                .map((tc) => {
                      'id': tc.id,
                      'type': tc.type,
                      'function': {
                        'name': tc.name,
                        'arguments': jsonEncode(tc.arguments)
                      },
                    })
                .toList(),
          });
        }
      } else {
        conversationMessages.add({
          'role': 'assistant',
          'content': response.content,
        });
      }

      for (final toolCall in effectiveToolCalls) {
        final toolName = toolCall.name;
        final toolArgs = toolCall.arguments;
        if (onToolActivity != null) {
          onToolActivity(ChatMessage(
            text: '$toolName wird ausgefuehrt...',
            isUser: false,
            type: MessageType.toolActivity,
          ));
        }
        ToolResult result;
        try {
          result = await _toolRegistry!.execute(toolName, toolArgs);
        } catch (e) {
          debugPrint('Tool loop: Tool $toolName threw exception: $e');
          result = ToolResult(
            toolName: toolName,
            parameters: toolArgs,
            result: 'Fehler bei Ausfuehrung von $toolName: $e',
            isError: true,
            displayText: 'Fehler bei $toolName',
          );
        }
        if (onToolActivity != null) {
          onToolActivity(ChatMessage(
            text: result.chatDisplay,
            isUser: false,
            type: MessageType.toolActivity,
          ));
        }
        conversationMessages
            .add(result.toToolResultMessage(toolCallId: toolCall.id));
        // Navigation: send special navigation message with map data
        if (toolName == 'open_navigation' && !result.isError && onToolActivity != null) {
          onToolActivity(ChatMessage(
            text: result.result.split('\n').first,
            isUser: false,
            type: MessageType.navigation,
            metadata: result.extraData,
          ));
        }
        // Location: send map pin with current location
        if (toolName == 'get_location' && !result.isError && onToolActivity != null) {
          final ed = result.extraData;
          if (ed != null && ed['lat'] != null && ed['lon'] != null) {
            onToolActivity(ChatMessage(
              text: result.result.split('\n').first,
              isUser: false,
              type: MessageType.locationMap,
              metadata: ed,
            ));
          }
        }
        if (toolName == 'set_reminder' && !result.isError) {
          await memory.addShortTerm('Erinnerung: $toolArgs', source: 'tool');
        }
      }
      // After tools executed, break loop and do final call without tools
      break;
    }

    // Final LLM call — summarize results for the user
    try {
      final finalResponse = await _llm.chat(
        systemPrompt: systemPrompt,
        messages: conversationMessages
            .map((m) => {
                  'role': (m['role'] as String?) ?? 'user',
                  'content': (m['content'] as String?) ?? '',
                })
            .toList(),
      );
      await Future.wait([
        memory.addShortTerm(userMessage, source: 'user'),
        memory.addShortTerm(finalResponse, source: 'assistant'),
      ]);
      // Auto-promote: check if conversation content is worth remembering long-term
      try {
        await memory.promoteIfImportant(userMessage, 'auto-assess: content from conversation');
        await memory.promoteIfImportant(finalResponse, 'auto-assess: response from conversation');
      } catch (e) {
        debugPrint('Memory promotion error: $e');
      }
      return finalResponse;
    } catch (e) {
      debugPrint('Tool loop: Final LLM call failed: $e');
      return 'Ich konnte die Anfrage nicht abschliessen. Bitte versuche es erneut.';
    }
  }

  List<ToolCall> _parseInlineToolCalls(String content) =>
      ToolCallParser.parseInline(content, _toolRegistry);

  List<ToolCall> _normalizeToolCalls(List<ToolCall> calls) {
    final normalized = <ToolCall>[];
    for (var i = 0; i < calls.length; i++) {
      final call = calls[i];
      if (_toolRegistry?.hasTool(call.name) != true) continue;
      normalized.add(ToolCall(
        id: call.id.isEmpty ? 'tool_call_$i' : call.id,
        type: call.type.isEmpty ? 'function' : call.type,
        name: call.name,
        arguments: call.arguments,
      ));
    }
    return normalized;
  }

  List<ToolCall> _fallbackToolCalls(String userMessage) {
    final registry = _toolRegistry;
    if (registry == null) return const [];
    final lower = userMessage.toLowerCase();

    if (registry.hasTool('music_intent') &&
        RegExp(r'\b(spiel|spiele|play|musik|song|lied|playlist|album|künstler|kuenstler)\b',
                caseSensitive: false)
            .hasMatch(lower)) {
      final query = userMessage
          .replaceAll(
              RegExp(r'^(spiel|spiele|play|mach)\s+(mir\s+)?',
                  caseSensitive: false),
              '')
          .replaceAll(
              RegExp(r'\s+(auf|in)\s+(spotify|youtube|soundcloud).*$',
                  caseSensitive: false),
              '')
          .trim();
      final appMatch =
          RegExp(r'\b(spotify|youtube|soundcloud)\b', caseSensitive: false)
              .firstMatch(lower);
      return [
        ToolCall(
            id: 'fallback_music_0',
            type: 'function',
            name: 'music_intent',
            arguments: {
              if (query.isNotEmpty && query.length < userMessage.length)
                'query': query,
              if (appMatch != null) 'app': appMatch.group(1),
            })
      ];
    }

    if (registry.hasTool('open_navigation') &&
        RegExp(r'(navigiere|navigier|navi|fahr\s+nach|fahr\s+zu|fahr\s+mich|fahre\s+nach|fahre\s+zu|route\s+zu|bring\s+mich\s+zum|bring\s+mich\s+zu|bring\s+mich\s+nach|wie\s+komme\s+ich\s+zum|wie\s+komme\s+ich\s+zu)',
                caseSensitive: false)
            .hasMatch(lower)) {
      final navMatch = RegExp(
        r'(?:navigiere|navigier|navi|fahr\s+nach|fahr\s+zu|fahr\s+mich|fahre\s+nach|fahre\s+zu|route\s+zu|bring\s+mich\s+zum|bring\s+mich\s+zu|bring\s+mich\s+nach|wie\s+komme\s+ich\s+zum|wie\s+komme\s+ich\s+zu)\s+(.+?)(?:\s+(?:bitte|mal|jetzt|fuer|für\s+mich|mit))?[.!?,;:\s]*$',
        caseSensitive: false,
      ).firstMatch(userMessage.trim());
      var destination = navMatch?.group(1)?.trim() ?? '';
      destination = destination
          .replaceAll(
              RegExp(r'^(?:mich\s+(?:zu|nach)\s+|zu\s+|nach\s+|zum\s+|zur\s+)'),
              '')
          .trim();
      if (destination.isNotEmpty) {
        String? mode;
        if (RegExp(r'(zu fuss|zu fuß|laufen|gehen|walking)',
                caseSensitive: false)
            .hasMatch(lower)) {
          mode = 'fuss';
        }
        if (RegExp(r'(fahrrad|rad|bike|cycling)', caseSensitive: false)
            .hasMatch(lower)) {
          mode = 'fahrrad';
        }
        if (RegExp(r'(oepnv|öpnv|transit|bus|bahn|zug)', caseSensitive: false)
            .hasMatch(lower)) {
          mode = 'oepnv';
        }
        return [
          ToolCall(
              id: 'fallback_nav_0',
              type: 'function',
              name: 'open_navigation',
              arguments: {
                'destination': destination,
                if (mode != null) 'mode': mode,
              })
        ];
      }
    }

    if (registry.hasTool('set_reminder') &&
        RegExp(r'(timer|wecker|erinnerung|erinnere|alarm|in\s+\d+\s*(?:minuten|min|sekunden|sec|stunden|std|h))',
                caseSensitive: false)
            .hasMatch(lower)) {
      final timeMatch = RegExp(
              r'in\s+(\d+)\s*(minuten|min|sekunden|sec|stunden|std|h)',
              caseSensitive: false)
          .firstMatch(userMessage);
      final amount =
          timeMatch == null ? 5 : int.tryParse(timeMatch.group(1)!) ?? 5;
      final unit = (timeMatch?.group(2) ?? 'minuten').toLowerCase();
      final minutes = unit.startsWith('std') || unit == 'h'
          ? amount * 60
          : unit.startsWith('sek') || unit == 'sec'
              ? (amount / 60).ceil()
              : amount;
      final title = userMessage
          .replaceAll(
              RegExp(
                  r'^(erinnere\s+mich\s+(?:an|daran)?|stell\s+(?:einen\s+)?(?:timer|wecker)?|timer|wecker|erinnerung)\s*',
                  caseSensitive: false),
              '')
          .replaceAll(
              RegExp(
                  r'\s+in\s+\d+\s*(?:minuten|min|sekunden|sec|stunden|std|h).*$',
                  caseSensitive: false),
              '')
          .trim();
      return [
        ToolCall(
            id: 'fallback_reminder_0',
            type: 'function',
            name: 'set_reminder',
            arguments: {
              'title': title.isEmpty ? 'Erinnerung' : title,
              'minutes_from_now': minutes,
            })
      ];
    }

    if (registry.hasTool('open_app')) {
      for (final known in _knownAppNames) {
        // "maps" gets handled by navigation fallback below, not open_app
        if (known == 'maps') continue;
        if (lower.contains(known)) {
          final hasOpenIntent = RegExp(
                  r'(öffne|oeffne|offne|starte|mach\s+.*auf|app|launch|aufmachen|anmachen|ich\s+will|ich\s+möchte|ich\s+moechte)',
                  caseSensitive: false)
              .hasMatch(lower);
          if (hasOpenIntent) {
            return [
              ToolCall(
                  id: 'fallback_app_0',
                  type: 'function',
                  name: 'open_app',
                  arguments: {'app': known})
            ];
          }
        }
      }
    }

    // "Google Maps" / "maps" → open_navigation with driving profile
    if (registry.hasTool('open_navigation') &&
        RegExp(r'\b(google\s*maps|maps|google\s*map|karte)\b', caseSensitive: false)
            .hasMatch(lower)) {
      // Try to extract destination from the message
      final destMatch = RegExp(
        r'(?:nach|zu|zum|zur|zu\s+magister|zu\s+herr|zu\s+frau)\s+(.+?)(?:\s+(?:bitte|mal|jetzt|[.!?,;:\s]))*$',
        caseSensitive: false,
      ).firstMatch(userMessage.trim());
      final destination = destMatch?.group(1)?.trim() ?? '';
      return [
        ToolCall(
            id: 'fallback_nav_gmaps_0',
            type: 'function',
            name: 'open_navigation',
            arguments: {
              if (destination.isNotEmpty) 'destination': destination,
              'profile': 'driving',
            })
      ];
    }

    return const [];
  }

  /// Detect LLM apology/error responses that should trigger a retry.
  /// Requires at least 2 apology signals to reduce false positives.
  static bool _isApologyResponse(String content) {
    final lower = content.toLowerCase().trim();
    if (lower.isEmpty) return false;
    // German + English apologies and error phrases
    const patterns = [
      'entschuldigung',
      'entschuldige',
      'es tut mir leid',
      'fehler aufgetreten',
      'hier ist was schief',
      'schiefgegangen',
      'schief gegangen',
      'something went wrong',
      'i apologize',
      'i\'m sorry',
      'ich kann nicht',
      'ich kann leider',
      'leider kann ich',
      'konnte nicht ge',
      'fehlgeschlagen',
    ];
    int matchCount = 0;
    for (final p in patterns) {
      if (lower.contains(p)) matchCount++;
      if (matchCount >= 2) return true;
    }
    return false;
  }

  /// Triggert sowohl PersonaEvolution als auch SelfIdentity-Introspection.
  /// PersonaEvolution-Erkenntnisse fließen als Erfahrungen ins Selbstbild.
  Future<void> _triggerEvolutionAndIntrospection(
    PersonaEvolutionService evolution,
    List<ChatMessage> history,
    String userMessage,
    String assistantReply,
  ) async {
    final context = 'Nutzer: $userMessage\nAssistant: $assistantReply';

    // 1. Vorher merken: welche Traits/Stil kennt die KI bereits?
    final preTraits = List<String>.from(evolution.learnedTraits);
    final preAvoid = List<String>.from(evolution.avoidTopics);

    // 2. PersonaEvolution (User-Stil lernen)
    try {
      await evolution.analyzeConversation(context);
    } catch (e) {
      debugPrint('Evolution error: $e');
    }

    // 3. Neue Erkenntnisse als Erfahrungen ins Selbstbild schreiben
    final selfIdentity = _selfIdentity;
    if (selfIdentity != null) {
      final newTraits = evolution.learnedTraits.where((t) => !preTraits.contains(t)).toList();
      final newAvoid = evolution.avoidTopics.where((a) => !preAvoid.contains(a)).toList();

      for (final trait in newTraits) {
        await selfIdentity.addExperience(
          'Ich habe gelernt: Mein Mensch schätzt folgendes an mir — $trait',
        );
      }
      for (final avoid in newAvoid) {
        await selfIdentity.addExperience(
          'Ich habe gelernt: Mein Mensch mag das Thema "$avoid" nicht.',
        );
      }

      // 4. SelfIdentity-Introspection (eigenes Selbstbild anpassen)
      try {
        final changes = await selfIdentity.introspect(context, _llm);
        if (changes != null && changes.isNotEmpty) {
          debugPrint('SelfIdentity updated after conversation: $changes');
        }
      } catch (e) {
        debugPrint('SelfIdentity introspection error: $e');
      }
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
