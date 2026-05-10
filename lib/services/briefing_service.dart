import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/ollama_cloud_service.dart';
import '../services/memory_service.dart';
import '../services/email_service.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_result.dart';

/// Aggregates data for the Morning Briefing and
/// presents it as structured sections.
class BriefingService {
  final OllamaCloudService _llm;
  final MemoryService _memory;
  final ToolRegistry _tools;
  final EmailService _email;

  BriefingService({
    required OllamaCloudService llm,
    required MemoryService memory,
    required ToolRegistry tools,
    EmailService? emailService,
  })  : _llm = llm,
        _memory = memory,
        _tools = tools,
        _email = emailService ?? EmailService();

  Future<MorningBriefing> generateBriefing() async {
    final sections = <BriefingSection>[];

    // ── Wetter ──
    try {
      final weather = await _tools.execute('get_weather', {});
      if (!weather.isError) {
        sections.add(BriefingSection(
          type: BriefingType.weather,
          title: 'Wetter',
          icon: '☀️',
          content: weather.result,
          displayText: weather.displayText,
        ));
      }
    } catch (e) {
      debugPrint('Briefing weather error: $e');
    }

    // ── Emails ──
    try {
      final digest = await _email.fetchUnreadEmails(maxResults: 10);
      if (digest.hasAny) {
        String content = 'Neue E-Mails: ${digest.totalUnread} ungelesen.';
        if (digest.hasImportant) {
          content += '\n\nWichtig:';
          for (final e in digest.importantEmails) {
            content += '\n- ${e.subject} (${e.sender.split('<').first.trim()})';
          }
        }
        sections.add(BriefingSection(
          type: BriefingType.email,
          title: 'E-Mails',
          icon: '✉️',
          content: content,
          displayText: digest.hasImportant
              ? '${digest.importantEmails.length} wichtig, ${digest.otherEmails.length} weitere'
              : '${digest.totalUnread} ungelesen',
          extraData: {'important': digest.importantEmails, 'other': digest.otherEmails},
        ));
      }
    } catch (e) {
      debugPrint('Briefing email error: $e');
    }

    // ── Kalender ──
    try {
      final cal = await _tools.execute('get_calendar_events', {'days_ahead': 3});
      if (!cal.isError && cal.result.contains('Termine')) {
        sections.add(BriefingSection(
          type: BriefingType.calendar,
          title: 'Termine',
          icon: '📅',
          content: cal.result,
          displayText: cal.displayText,
        ));
      }
    } catch (e) {
      debugPrint('Briefing calendar error: $e');
    }

    // ── News — AI Models ──
    try {
      final aiNews = await _tools.execute('web_search', {
        'query': 'new AI models 2026 latest releases artificial intelligence',
        'max_results': 3,
      });
      if (!aiNews.isError) {
        sections.add(BriefingSection(
          type: BriefingType.news,
          title: 'AI & Tech',
          icon: '🤖',
          content: aiNews.result,
          displayText: 'Neues aus der AI-Welt',
          sourceQuery: 'AI models',
        ));
      }
    } catch (e) {
      debugPrint('Briefing AI news error: $e');
    }

    // ── News — Robotics / Gadgets ──
    try {
      final gadgetNews = await _tools.execute('web_search', {
        'query': 'household robotics consumer gadgets 2026 new devices',
        'max_results': 3,
      });
      if (!gadgetNews.isError) {
        sections.add(BriefingSection(
          type: BriefingType.news,
          title: 'Gadgets & Robots',
          icon: '🏠',
          content: gadgetNews.result,
          displayText: 'Neue Gadgets & Haushaltsroboter',
          sourceQuery: 'gadgets robotics',
        ));
      }
    } catch (e) {
      debugPrint('Briefing gadget news error: $e');
    }

    // ── Wichtige Erinnerungen ──
    try {
      final recent = _memory.shortTermMemories.take(10).toList();
      final important = recent
          .where((m) =>
              m.source == 'user' &&
              (m.content.toLowerCase().contains('wichtig') ||
               m.content.toLowerCase().contains('termin') ||
               m.content.toLowerCase().contains('deadline') ||
               m.content.toLowerCase().contains('erinner')))
          .toList();
      if (important.isNotEmpty) {
        final lines = important.map((m) => '- ${m.content}').join('\n');
        sections.add(BriefingSection(
          type: BriefingType.tasks,
          title: 'Erinnerungen',
          icon: '📌',
          content: lines,
          displayText: '${important.length} wichtige Erinnerungen',
        ));
      }
    } catch (e) {
      debugPrint('Briefing memory error: $e');
    }

    // ── LLM Summary ──
    String? summary;
    try {
      final context = sections.map((s) => '${s.title}: ${s.displayText ?? s.content.substring(0, s.content.length < 300 ? s.content.length : 300)}').join('\n');
      final emailContext = sections
          .where((s) => s.type == BriefingType.email && s.extraData != null)
          .map((s) => s.extraData!['important']?.map((e) => '- ${e.subject} (${e.sender})')?.join('\n') ?? '')
          .join('\n');
      summary = await _llm.chat(
        systemPrompt:
            'Du bist Kiro, ein persönlicher KI-Assistent. Erstelle einen kurzen, motivierenden Morgenbrief (max 4 Sätze). '
            'Wenn wichtige E-Mails anstehen, erwähne das und gib einen konkreten Handlungstipp. '
            'Sei warm, persönlich, nicht zu formell. Keine Aufzählungen, kein Markdown.',
        messages: [
          {'role': 'user', 'content': 'Mein Morgen-Daten:\n$context${emailContext.isNotEmpty ? "\n\nWichtige E-Mails:\n$emailContext" : ""}\n\nPersönlicher Morgenbrief:'}
        ],
        model: _llm.fallbackModel,
        temperature: 0.8,
      );
    } catch (e) {
      debugPrint('Briefing summary error: $e');
    }

    final totalUnread = sections
        .where((s) => s.type == BriefingType.email)
        .map((s) => (s.extraData?['important'] as List<dynamic>? ?? []).length +
            (s.extraData?['other'] as List<dynamic>? ?? []).length)
        .fold(0, (a, b) => a + b);

    final briefing = MorningBriefing(
      sections: sections,
      summary: summary ?? 'Guten Morgen! Dein persönlicher Briefing ist bereit.',
      generatedAt: DateTime.now(),
      totalUnread: totalUnread,
    );

    // Save to memory for continuity
    try {
      await _memory.addShortTerm(
        'Morgenbriefing: ${sections.map((s) => s.title).join(', ')}',
        source: 'briefing',
      );
    } catch (_) {}

    return briefing;
  }
}

enum BriefingType { weather, calendar, email, news, tasks, summary }

class BriefingSection {
  final BriefingType type;
  final String title;
  final String icon;
  final String content;
  final String? displayText;
  final String? sourceQuery;
  final Map<String, dynamic>? extraData;

  BriefingSection({
    required this.type,
    required this.title,
    required this.icon,
    required this.content,
    this.displayText,
    this.sourceQuery,
    this.extraData,
  });
}

class MorningBriefing {
  final List<BriefingSection> sections;
  final String summary;
  final DateTime generatedAt;
  final int totalUnread;

  MorningBriefing({
    required this.sections,
    required this.summary,
    required this.generatedAt,
    this.totalUnread = 0,
  });
}
