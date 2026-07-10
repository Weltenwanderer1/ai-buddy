import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'open_app_tool.dart';
import 'tool_definition.dart';
import 'tool_interface.dart';
import 'tool_result.dart';

/// Best-effort music action.
///
/// Android does not allow arbitrary media control in third-party apps without
/// Accessibility / notification-listener integration or a music provider SDK.
/// This tool therefore opens a music app and, when a query is provided, sends a
/// generic media/web search intent so the user can start playback quickly.
class MusicIntentTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'music_intent',
    description: 'Oeffnet Musik-App, sucht optional nach Song/Artist/Playlist.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Song, Künstler, Album oder Playlist, optional',
        },
        'app': {
          'type': 'string',
          'description':
              'Bevorzugte Musik-App, z.B. spotify, youtube, soundcloud. Optional.',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  static String? resolveMusicPackage(String app) {
    return OpenAppTool.resolvePackageName(app.trim().toLowerCase());
  }

  /// Provider-specific search links prevent Android from resolving a generic
  /// media search through the wrong app (notably YouTube instead of Spotify).
  static Uri buildSearchUri({required String app, required String query}) {
    final normalized = app.trim().toLowerCase();
    if (normalized == 'spotify') {
      return Uri.parse('spotify:search:${Uri.encodeComponent(query)}');
    }
    if (normalized == 'youtube' || normalized == 'youtube music') {
      return Uri.https('www.youtube.com', '/results', {'search_query': query});
    }
    if (normalized == 'soundcloud') {
      return Uri.https('soundcloud.com', '/search', {'q': query});
    }
    return Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
    );
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query =
        (parameters['query'] as String? ?? parameters['song'] as String? ?? '')
            .trim();
    final app = (parameters['app'] as String? ?? 'spotify').trim();

    try {
      if (query.isNotEmpty) {
        final appPackage = resolveMusicPackage(app);
        if (appPackage == null) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Unbekannte Musik-App: $app',
            isError: true,
            displayText: 'Musik-App nicht gefunden',
          );
        }
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: buildSearchUri(app: app, query: query).toString(),
          package: appPackage,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Musiksuche gestartet: $query${app.isNotEmpty ? ' in $app' : ''}. Hinweis: Direkte Wiedergabe hängt von der Musik-App ab.',
          displayText: '🎵 Musiksuche: $query',
        );
      }

      final packageName = OpenAppTool.resolvePackageName(app) ??
          OpenAppTool.resolvePackageName('spotify');
      if (packageName == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Musik-App bekannt.',
          isError: true,
          displayText: 'Keine Musik-App gefunden',
        );
      }
      final launched = await OpenAppTool().execute({'app': packageName});
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: launched.isError
            ? launched.result
            : 'Musik-App geöffnet: $app. Hinweis: Direkte Wiedergabe braucht Nutzerinteraktion oder Provider-Integration.',
        isError: launched.isError,
        displayText:
            launched.isError ? launched.displayText : '🎵 $app geöffnet',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Musik-Aktion fehlgeschlagen: $e',
        isError: true,
        displayText: 'Musik-Aktion fehlgeschlagen',
      );
    }
  }
}
