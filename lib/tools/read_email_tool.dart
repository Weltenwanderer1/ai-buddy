import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Reads recent emails via IMAP.
class ReadEmailTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'read_email',
    description: 'Liest die neuesten E-Mails via IMAP.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'folder': {
          'type': 'string',
          'description': 'E-Mail-Ordner (Standard INBOX)',
        },
        'limit': {
          'type': 'integer',
          'description': 'Maximale Anzahl E-Mails (1-10, Standard 5)',
        },
        'unread_only': {
          'type': 'boolean',
          'description': 'Nur ungelesene E-Mails (Standard false)',
        },
      },
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// IMAP server address (e.g. imap.gmail.com)
  final String server;
  /// IMAP port (usually 993 for SSL)
  final int port;
  /// Email address for login
  final String email;
  /// Password or app-specific password
  final String password;
  /// Use SSL/TLS connection
  final bool useSsl;

  ReadEmailTool({
    required this.server,
    required this.port,
    required this.email,
    required this.password,
    this.useSsl = true,
  });

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final folder = (parameters['folder'] as String?) ?? 'INBOX';
    final limit = ((parameters['limit'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final unreadOnly = parameters['unread_only'] as bool? ?? false;

    if (email.isEmpty || password.isEmpty || server.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: E-Mail nicht konfiguriert. Bitte in den Einstellungen IMAP-Server, E-Mail-Adresse und Passwort eintragen.',
        isError: true,
        displayText: '❌ E-Mail nicht konfiguriert',
      );
    }

    Socket? socket;
    try {
      // Connect
      if (useSsl) {
        socket = await SecureSocket.connect(server, port,
            timeout: const Duration(seconds: 10));
      } else {
        socket = await Socket.connect(server, port,
            timeout: const Duration(seconds: 10));
      }

      final session = _ImapSession(socket);

      // LOGIN
      final loginResp = await session.command(
          'a1', 'LOGIN ${_quote(email)} ${_quote(password)}');
      if (!loginResp.contains('a1 OK')) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Login fehlgeschlagen. Prüfe E-Mail/Passwort. Bei Gmail brauchst du ein App-Passwort (nicht das normale Passwort).',
          isError: true,
          displayText: '❌ Login fehlgeschlagen',
        );
      }

      // SELECT folder
      final selectResp = await session.command('a2', 'SELECT ${_quote(folder)}');
      if (!selectResp.contains('a2 OK')) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Ordner $folder nicht gefunden.',
          isError: true,
          displayText: '❌ Ordner nicht gefunden',
        );
      }

      // UID SEARCH — liefert UIDs, die zu UID FETCH passen. (Plain SEARCH
      // liefert Sequenznummern; die als UIDs zu fetchen holt falsche Mails.)
      final searchResp = await session.command(
          'a3', unreadOnly ? 'UID SEARCH UNSEEN' : 'UID SEARCH ALL');
      final uids = _extractUids(searchResp);

      if (uids.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: unreadOnly ? 'Keine ungelesenen E-Mails.' : 'Keine E-Mails gefunden.',
          displayText: unreadOnly ? '📭 Keine ungelesenen E-Mails' : '📭 Keine E-Mails',
        );
      }

      // Fetch latest N
      final fetchUids = uids.length > limit ? uids.sublist(uids.length - limit) : uids;
      final uidStr = fetchUids.join(',');
      final fetchResp = await session.command('a4',
          'UID FETCH $uidStr (BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)])');

      final emails = _parseEmails(fetchResp);

      // LOGOUT (best effort)
      try { await session.command('a5', 'LOGOUT'); } catch (_) {}

      if (emails.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'E-Mails gefunden aber keine Daten extrahierbar.',
          displayText: '📭 E-Mails gefunden',
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('E-Mails (${emails.length}):');
      buffer.writeln();
      // Neueste zuerst
      for (final e in emails.reversed) {
        buffer.writeln('--- ${e['subject'] ?? '(Kein Betreff)'} ---');
        buffer.writeln('Von: ${e['from'] ?? 'Unbekannt'}');
        buffer.writeln('Datum: ${e['date'] ?? 'Unbekannt'}');
        buffer.writeln();
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '📧 ${emails.length} E-Mail(s)',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ E-Mail-Fehler',
      );
    } finally {
      socket?.destroy();
    }
  }

  /// IMAP quoted-string: umschließt mit ", escaped \ und ".
  static String _quote(String s) =>
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  List<String> _extractUids(String response) {
    final uids = <String>[];
    for (final line in response.split('\n')) {
      if (line.contains('SEARCH')) {
        final match = RegExp(r'SEARCH\s+(.+)').firstMatch(line);
        if (match != null) {
          for (final n in match.group(1)!.trim().split(' ')) {
            if (RegExp(r'^\d+$').hasMatch(n.trim())) {
              uids.add(n.trim());
            }
          }
        }
      }
    }
    return uids;
  }

  List<Map<String, String?>> _parseEmails(String response) {
    final emails = <Map<String, String?>>[];

    String? subject;
    String? from;
    String? date;
    bool inMessage = false;

    void flush() {
      if (inMessage && (subject != null || from != null)) {
        emails.add({
          'subject': _decodeMimeWords(subject ?? '(Kein Betreff)'),
          'from': _decodeMimeWords(from ?? 'Unbekannt'),
          'date': date ?? 'Unbekannt',
        });
      }
      subject = null;
      from = null;
      date = null;
    }

    String? lastHeader; // für gefaltete (mehrzeilige) Header

    for (final raw in response.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('* ') && line.contains('FETCH')) {
        // Neue Nachricht beginnt → vorherige abschließen
        flush();
        inMessage = true;
        lastHeader = null;
      } else if (line.toLowerCase().startsWith('subject:')) {
        subject = line.substring('subject:'.length).trim();
        lastHeader = 'subject';
      } else if (line.toLowerCase().startsWith('from:')) {
        from = line.substring('from:'.length).trim();
        lastHeader = 'from';
      } else if (line.toLowerCase().startsWith('date:')) {
        date = line.substring('date:'.length).trim();
        lastHeader = 'date';
      } else if ((line.startsWith(' ') || line.startsWith('\t')) && lastHeader != null) {
        // Fortsetzungszeile eines gefalteten Headers (RFC 2822 folding)
        final cont = line.trim();
        switch (lastHeader) {
          case 'subject': subject = '${subject ?? ''} $cont'; break;
          case 'from': from = '${from ?? ''} $cont'; break;
          case 'date': date = '${date ?? ''} $cont'; break;
        }
      } else {
        lastHeader = null;
      }
    }
    flush();

    return emails;
  }

  /// Dekodiert RFC-2047 encoded-words (=?charset?B|Q?...?=) — nötig für
  /// Umlaute in Betreff/Absender.
  static String _decodeMimeWords(String input) {
    return input.replaceAllMapped(
      RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?='),
      (m) {
        try {
          final encoding = m.group(2)!.toUpperCase();
          final text = m.group(3)!;
          List<int> bytes;
          if (encoding == 'B') {
            bytes = base64.decode(text);
          } else {
            // Q-Encoding: _ = Leerzeichen, =XX = Hex-Byte
            final sb = <int>[];
            for (var i = 0; i < text.length; i++) {
              final ch = text[i];
              if (ch == '_') {
                sb.add(0x20);
              } else if (ch == '=' && i + 2 < text.length) {
                final hex = int.tryParse(text.substring(i + 1, i + 3), radix: 16);
                if (hex != null) { sb.add(hex); i += 2; } else { sb.add(ch.codeUnitAt(0)); }
              } else {
                sb.add(ch.codeUnitAt(0));
              }
            }
            bytes = sb;
          }
          // Charset: utf-8 und ascii direkt; latin-1 via Latin1; sonst utf-8-Versuch
          final cs = m.group(1)!.toLowerCase();
          if (cs.contains('8859') || cs.contains('latin')) {
            return latin1.decode(bytes, allowInvalid: true);
          }
          return utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          return m.group(0)!;
        }
      },
    );
  }
}

/// Kleine IMAP-Session: EIN dauerhafter Socket-Listener füllt einen Puffer,
/// `command()` schreibt und wartet auf die getaggte Statuszeile.
///
/// Wichtig: Der Stream wird nur einmal abonniert — mehrfaches `await for`
/// auf demselben StreamController wirft nach dem ersten Abbruch
/// "Stream has already been listened to".
class _ImapSession {
  final Socket _socket;
  final StringBuffer _buffer = StringBuffer();
  Completer<void>? _onData;
  bool _closed = false;

  _ImapSession(Socket socket) : _socket = socket {
    socket.listen(
      (data) {
        _buffer.write(utf8.decode(data, allowMalformed: true));
        _onData?.complete();
        _onData = null;
      },
      onDone: () {
        _closed = true;
        _onData?.complete();
        _onData = null;
      },
      onError: (_) {
        _closed = true;
        _onData?.complete();
        _onData = null;
      },
    );
  }

  /// Sendet `cmd` mit Tag und wartet, bis `tag OK/NO/BAD` im Puffer erscheint.
  Future<String> command(String tag, String cmd,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final start = _buffer.length;
    _socket.write('$tag $cmd\r\n');
    final deadline = DateTime.now().add(timeout);
    final done = RegExp('^$tag (OK|NO|BAD)', multiLine: true);

    while (true) {
      final resp = _buffer.toString().substring(start);
      if (done.hasMatch(resp)) return resp;
      if (_closed) return resp;
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        throw TimeoutException('IMAP-Timeout bei: $cmd');
      }
      final c = Completer<void>();
      _onData = c;
      await c.future.timeout(remaining, onTimeout: () {});
    }
  }
}
