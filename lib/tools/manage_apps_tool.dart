import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// App management: list installed apps, get app details, uninstall, search Play Store.
class ManageAppsTool implements ToolInterface {
  static const MethodChannel _channel = MethodChannel('com.aibuddy.app/apps');

  static const _definition = ToolDefinition(
    name: 'manage_apps',
    description:
        'Installierte Apps verwalten. '
        'Aktionen: "list" (alle Apps), "details" (zu einer App), '
        '"uninstall" (App deinstallieren), "search_store" (im Play Store suchen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: list, details, uninstall, search_store',
          'enum': ['list', 'details', 'uninstall', 'search_store'],
        },
        'packageName': {
          'type': 'string',
          'description': 'Package-Name z.B. "com.spotify.music". Fuer details und uninstall erforderlich.',
        },
        'includeSystem': {
          'type': 'boolean',
          'description': 'Bei list: auch System-Apps anzeigen. Default: false.',
        },
        'query': {
          'type': 'string',
          'description': 'Bei search_store: Suchbegriff im Play Store z.B. "Spotify" oder "pdf reader".',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?)?.trim() ?? 'list';

    switch (action) {
      case 'list':
        return _listApps(parameters);
      case 'details':
        return _getDetails(parameters);
      case 'uninstall':
        return _uninstallApp(parameters);
      case 'search_store':
        return _searchStore(parameters);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action. Nutze list, details, uninstall oder search_store.',
          isError: true,
        );
    }
  }

  Future<ToolResult> _listApps(Map<String, dynamic> parameters) async {
    final includeSystem = parameters['includeSystem'] as bool? ?? false;
    try {
      final dynamic result = await _channel.invokeMethod('getInstalledApps', {
        'includeSystem': includeSystem,
      });
      // MethodChannel returns List<Object?> of Map<Object?,Object?> — .cast to
      // Map<String,dynamic> would throw at first access. Rebuild the maps.
      final apps = (result as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      if (apps.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Apps gefunden.',
          displayText: '📦 Keine Apps',
        );
      }

      final count = apps.length;
      final buffer = StringBuffer('Installierte Apps ($count):\n');
      for (final app in apps.take(50)) {
        final name = app['name'] ?? '???';
        final pkg = app['packageName'] ?? '???';
        final version = app['version'] ?? '?';
        final system = app['isSystem'] == true ? ' [S]' : '';
        buffer.writeln('- $name ($pkg) v$version$system');
      }
      if (apps.length > 50) {
        buffer.writeln('... und ${apps.length - 50} weitere.');
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '📦 $count Apps installiert',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler beim Laden',
      );
    }
  }

  Future<ToolResult> _getDetails(Map<String, dynamic> parameters) async {
    final packageName = (parameters['packageName'] as String?)?.trim() ?? '';
    if (packageName.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: packageName erforderlich.',
        isError: true,
        displayText: '❌ Kein Package-Name',
      );
    }

    try {
      final dynamic result = await _channel.invokeMethod('getAppDetails', {
        'packageName': packageName,
      });
      // Channel returns Map<Object?,Object?>; rebuild as Map<String,dynamic>.
      final details = result == null ? null : Map<String, dynamic>.from(result as Map);

      if (details == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'App "$packageName" nicht gefunden.',
          isError: true,
          displayText: '❌ App nicht gefunden',
        );
      }

      final info = StringBuffer('App-Details:\n');
      info.writeln('Name: ${details['name']}');
      info.writeln('Package: ${details['packageName']}');
      info.writeln('Version: ${details['version']}');
      info.writeln('System-App: ${details['isSystem'] == true ? 'Ja' : 'Nein'}');
      info.writeln('Aktiviert: ${details['isEnabled'] == true ? 'Ja' : 'Nein'}');
      info.writeln('Target SDK: ${details['targetSdk']}');
      final installRaw = details['firstInstallTime'];
      if (installRaw != null) {
        // firstInstallTime is epoch milliseconds (a Long), not an ISO string.
        final installDate = installRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(installRaw.toInt())
            : DateTime.tryParse(installRaw.toString());
        if (installDate != null) {
          info.writeln('Installiert: ${installDate.year}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}');
        }
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: info.toString(),
        displayText: '📦 ${details['name']} v${details['version']}',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
      );
    }
  }

  Future<ToolResult> _uninstallApp(Map<String, dynamic> parameters) async {
    final packageName = (parameters['packageName'] as String?)?.trim() ?? '';
    if (packageName.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: packageName erforderlich.',
        isError: true,
        displayText: '❌ Kein Package-Name',
      );
    }

    try {
      final dynamic result = await _channel.invokeMethod('uninstallApp', {
        'packageName': packageName,
      });
      final success = result as bool? ?? false;

      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Deinstallations-Dialog fuer $packageName geoeffnet. Nutzer muss bestaetigen.',
          displayText: '🗑️ Deinstallation gestartet',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Deinstallation fuer $packageName fehlgeschlagen.',
          isError: true,
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
      );
    }
  }

  Future<ToolResult> _searchStore(Map<String, dynamic> parameters) async {
    final query = (parameters['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: query erforderlich.',
        isError: true,
        displayText: '❌ Kein Suchbegriff',
      );
    }

    try {
      final dynamic result = await _channel.invokeMethod('openAppStore', {
        'query': query,
      });
      final success = result as bool? ?? false;

      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Play Store mit Suche nach "$query" geoeffnet.',
          displayText: '🔍 Play Store: $query',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Play Store konnte nicht geoeffnet werden.',
          isError: true,
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
      );
    }
  }
}
