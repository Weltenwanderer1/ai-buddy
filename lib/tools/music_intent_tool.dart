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
    description:
        'Best-effort Musik-Aktion: öffnet eine Musik-App (z.B. Spotify/YouTube Music/SoundCloud) und sucht optional nach Song, Album, Künstler oder Playlist. Nutze dies für Wünsche wie "spiel mir Musik", "spiel Queen", "mach Spotify-Musik an". Echte Wiedergabe ohne Nutzerinteraktion ist ohne Accessibility/SDK nicht garantiert.',
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

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query =
        (parameters['query'] as String? ?? parameters['song'] as String? ?? '')
            .trim();
    final app = (parameters['app'] as String? ?? 'spotify').trim();

    try {
      if (query.isNotEmpty) {
        final appPackage = OpenAppTool.resolvePackageName(app);
        final intent = AndroidIntent(
          action: 'android.intent.action.MEDIA_SEARCH',
          package: appPackage,
          arguments: {
            'query': query,
            'android.intent.extra.TITLE': query,
            'android.intent.extra.TEXT': query,
          },
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
