import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service that fetches and prioritizes emails from Gmail via the gog CLI.
/// Filters out newsletters/promotions and surfaces truly important emails.
class EmailService {
  static const int _maxEmails = 15;

  /// Fetches unread inbox emails and classifies them by importance.
  Future<EmailDigest> fetchUnreadEmails({int maxResults = 15}) async {
    try {
      final result = await _runGogGmailSearch('is:inbox is:unread', maxResults);
      final threads = _parseJson(result.stdout);

      final emails = <EmailMessage>[];
      for (final thread in threads) {
        final msg = EmailMessage.fromJson(thread);
        // Skip obvious junk
        if (_isJunk(msg)) continue;
        emails.add(msg);
      }

      // Sort: important first, then by date
      emails.sort((a, b) {
        if (a.isImportant != b.isImportant) {
          return a.isImportant ? -1 : 1;
        }
        return b.date.compareTo(a.date);
      });

      final important = emails.where((e) => e.isImportant).toList();
      final other = emails.where((e) => !e.isImportant).toList();

      return EmailDigest(
        importantEmails: important.take(5).toList(),
        otherEmails: other.take(5).toList(),
        totalUnread: emails.length,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('EmailService fetch error: $e');
      return EmailDigest(
        importantEmails: [],
        otherEmails: [],
        totalUnread: 0,
        fetchedAt: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Generate an AI draft reply for an important email.
  Future<String?> generateReplyDraft(String subject, String sender, String? snippet) async {
    // This is a placeholder — actual implementation would call the LLM
    // via ChatService with a system prompt for email drafting.
    return null;
  }

  static Future<ProcessResult> _runGogGmailSearch(String query, int maxResults) async {
    final envFile = File('${Platform.environment['HOME']}/.config/gog/env');
    final env = <String, String>{};
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        if (line.trim().startsWith('export ')) {
          final kv = line.trim().substring(7).split('=');
          if (kv.length == 2) {
            env[kv[0]] = kv[1].replaceAll('"', '');
          }
        }
      }
    }

    final result = await Process.run(
      'bash',
      [
        '-c',
        'source ~/.config/gog/env 2>/dev/null; gog gmail search \'$query\' --max $maxResults --json --results-only',
      ],
      environment: {...Platform.environment, ...env},
      workingDirectory: Platform.environment['HOME'],
    );
    return result;
  }

  static List<Map<String, dynamic>> _parseJson(String output) {
    try {
      final trimmed = output.trim();
      if (trimmed.isEmpty || trimmed == '[]') return [];
      // gog returns either a JSON array directly or an object with "threads" key
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map && decoded['threads'] is List) {
        return (decoded['threads'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('EmailService JSON parse error: $e\nOutput: ${output.substring(0, output.length < 200 ? output.length : 200)}');
      return [];
    }
  }

  static bool _isJunk(EmailMessage msg) {
    final lowerSubject = msg.subject.toLowerCase();
    final lowerSender = msg.sender.toLowerCase();

    // Auto-categorized as promotions by Gmail
    if (msg.labels.contains('CATEGORY_PROMOTIONS')) return true;

    // Known promotional senders
    final promoSenders = [
      'noreply', 'no-reply', 'newsletter', 'marketing',
      'info@', 'offers@', 'deals@', 'promo@',
      'netflix.com', 'spotify.com', 'amazon.com',
      'newsletter@', 'updates@', 'notifications@',
    ];
    if (promoSenders.any((s) => lowerSender.contains(s))) {
      // BUT keep if subject looks important
      final importantTerms = ['rechnung', 'zahlung', 'vertrag', 'kündigung', 'wichtig', 'dringend', 'termin', 'bestätigung', 'invoice', 'payment'];
      if (!importantTerms.any((t) => lowerSubject.contains(t))) {
        return true;
      }
    }

    // Newsletter subjects
    final newsletterPatterns = [
      'weekly', 'monatlich', 'newsletter', 'digest', 'rundschreiben',
      'deine woche', 'top stories', 'empfohlen', 'für dich',
    ];
    if (newsletterPatterns.any((p) => lowerSubject.contains(p))) return true;

    // Social / Forums
    if (msg.labels.contains('CATEGORY_SOCIAL')) return true;

    return false;
  }
}

class EmailMessage {
  final String id;
  final String subject;
  final String sender;
  final DateTime date;
  final List<String> labels;
  final int messageCount;
  final bool isImportant;

  EmailMessage({
    required this.id,
    required this.subject,
    required this.sender,
    required this.date,
    required this.labels,
    required this.messageCount,
    this.isImportant = false,
  });

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    final labels = (json['labels'] as List<dynamic>? ?? []).cast<String>();
    final subject = json['subject'] as String? ?? '(Kein Betreff)';
    final lowerSubject = subject.toLowerCase();

    // Heuristic importance scoring
    final importantTerms = [
      'rechnung', 'zahlung', 'vertrag', 'kündigung', 'wichtig', 'dringend',
      'termin', 'bestätigung', 'invoice', 'payment', 'deadline', 'frist',
      'behörde', 'ams', 'waff', 'jobs plus', 'kindercompany', 'schule',
      'anmeldung', 'bewerbung', 'gehalt', 'lohn', 'krankenkasse',
    ];
    final isImportant = labels.contains('IMPORTANT') ||
        importantTerms.any((t) => lowerSubject.contains(t));

    final dateStr = json['date'] as String? ?? '';
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return EmailMessage(
      id: json['id'] as String? ?? '',
      subject: subject,
      sender: json['from'] as String? ?? 'Unbekannt',
      date: parsedDate,
      labels: labels,
      messageCount: json['messageCount'] as int? ?? 1,
      isImportant: isImportant,
    );
  }
}

class EmailDigest {
  final List<EmailMessage> importantEmails;
  final List<EmailMessage> otherEmails;
  final int totalUnread;
  final DateTime fetchedAt;
  final String? error;

  EmailDigest({
    required this.importantEmails,
    required this.otherEmails,
    required this.totalUnread,
    required this.fetchedAt,
    this.error,
  });

  bool get hasImportant => importantEmails.isNotEmpty;
  bool get hasAny => importantEmails.isNotEmpty || otherEmails.isNotEmpty;
}
