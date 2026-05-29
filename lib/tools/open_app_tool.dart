import '../services/android_app_launcher_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class OpenAppTool implements ToolInterface {
  /// Map of common German app names to Android package names.
  /// Includes canonical forms — normalization of Umlauts/variants happens in _normalizeAppName.
  static const _knownApps = {
    'whatsapp': 'com.whatsapp',
    'telegram': 'org.telegram.messenger',
    'youtube': 'com.google.android.youtube',
    'maps': 'com.google.android.apps.maps',
    'google maps': 'com.google.android.apps.maps',
    'chrome': 'com.android.chrome',
    'browser': 'com.android.chrome',
    'gmail': 'com.google.android.gm',
    'email': 'com.google.android.gm',
    'kamera': 'com.android.camera',
    'camera': 'com.android.camera',
    'fotos': 'com.google.android.apps.photos',
    'photos': 'com.google.android.apps.photos',
    'google fotos': 'com.google.android.apps.photos',
    'einstellungen': 'com.android.settings',
    'settings': 'com.android.settings',
    'kalender': 'com.google.android.calendar',
    'calendar': 'com.google.android.calendar',
    'spotify': 'com.spotify.music',
    'netflix': 'com.netflix.mediaclient',
    'instagram': 'com.instagram.android',
    'uhr': 'com.google.android.deskclock',
    'clock': 'com.google.android.deskclock',
    'rechner': 'com.google.android.calculator',
    'calculator': 'com.google.android.calculator',
    'notizen': 'com.google.android.keep',
    'keep': 'com.google.android.keep',
    'google keep': 'com.google.android.keep',
    'tiktok': 'com.zhiliaoapp.musically',
    'reddit': 'com.reddit.frontpage',
    'twitter': 'com.twitter.android',
    'x': 'com.twitter.android',
    'amazon': 'com.amazon.mShop.android.shopping',
    'ebay': 'com.ebay.mobile',
    'paypal': 'com.paypal.android.p2pmobile',
    'wetter': 'com.google.android.apps.weather',
    'weather': 'com.google.android.apps.weather',
    'downloads': 'com.android.documentsui',
    'dateien': 'com.android.documentsui',
    'files': 'com.android.documentsui',
    'linkedin': 'com.linkedin.android',
    'pinterest': 'com.pinterest',
    'snapchat': 'com.snapchat.android',
    'twitch': 'tv.twitch.android.app',
    'discord': 'com.discord',
    'prime video': 'com.amazon.avod.thirdpartyclient',
    'disney+': 'com.disney.disneyplus',
    'disney plus': 'com.disney.disneyplus',
    'signal': 'org.thoughtcrime.securesms',
    'threema': 'com.threema.app',
    'firefox': 'org.mozilla.firefox',
    'samsung internet': 'com.sec.android.app.sbrowser',
    'outlook': 'com.microsoft.outlook',
    'teams': 'com.microsoft.teams',
    'zoom': 'us.zoom.videomeetings',
    'uber': 'com.ubercab',
    'lyft': 'me.lyft.android',
    'booking': 'com.booking',
    'airbnb': 'com.airbnb.android',
    'wikipedia': 'org.wikipedia',
    'vlc': 'org.videolan.vlc',
    'shazam': 'com.shazam.android',
    'soundcloud': 'com.soundcloud.android',
    'google play': 'com.android.vending',
    'play store': 'com.android.vending',
    'app store': 'com.android.vending',
  };

  static const _definition = ToolDefinition(
    name: 'open_app',
    description:
        'Oeffnet eine App. Parameter: App-Name (z.B. "spotify", "whatsapp", "telegram", "youtube", "maps", "chrome", "gmail", "netflix", "instagram", "tiktok", "discord", "signal", "firefox") oder Package-Name.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'app': {
          'type': 'string',
          'description':
              'Name der App (z.B. "spotify", "whatsapp") oder Package-Name (z.B. "com.spotify.music")',
        },
      },
      'required': ['app'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Normalize an app name: handle German Umlauts, oe/ae/ue variants,
  /// filler words, extra whitespace, and common aliases.
  static String normalizeAppName(String input) {
    var name = input.trim().toLowerCase();

    // Remove leading action commands if the whole user phrase was passed in.
    name = name
        .replaceAll(
          RegExp(
              r'^(öffne|oeffne|offne|öffnen|oeffnen|offnen|starte|launch|play|mach\s+mir|mach|ich\s+will|ich\s+möchte|ich\s+brauche|bring\s+mich\s+(zu|zum|zur)|ruf\s+.*\s+auf|lass\s+uns|könnest\s+du|kannst\s+du|anmachen|aufmachen)\s+',
              caseSensitive: false),
          '',
        )
        .trim();
    name = name
        .replaceAll(
          RegExp(r'^mach\s+(.+?)\s+auf$', caseSensitive: false),
          r'$1',
        )
        .trim();
    // Remove trailing action words: "aufmachen", "anmachen", "öffnen", "starten", "app" etc.
    name = name
        .replaceAll(
          RegExp(
              r'\s+(aufmachen|anmachen|öffnen|oeffnen|offnen|starten|app|an|auf|ein|mal)$',
              caseSensitive: false,
              unicode: true),
          '',
        )
        .trim();

    // Remove common German filler words/particles.
    name = name
        .replaceAll(
            RegExp(
                r'\b(bitte|mal|gern|einfach|doch|ja|halt|wohl|schon|nun|denn|eben|jetzt|für mich|fuer mich)\b'),
            '')
        .trim();

    // Remove articles: "die app", "der browser", "das telegram" etc.
    name = name
        .replaceAll(
            RegExp(
                r'^(die|der|das|den|dem|des|ein|eine|einer|eines|einem|einen)\s+'),
            '')
        .trim();

    // Normalize German Umlauts: ö→oe, ä→ae, ü→ue (canonical German alternate spellings)
    // Then also map the Umlaut directly for lookup.
    // We store in _knownApps with Umlauts where appropriate, so we also need
    // a version that converts ae→ä etc for matching.
    // Strategy: produce a canonical lookup key with Umlauts restored where appropriate.

    // Strategy: produce a canonical lookup key with Umlauts restored where appropriate.

    // Convert ae→ä, oe→ö, ue→ü in known contexts
    // But only for app name matching — common apps like "uber" should stay "uber"
    // We'll do a two-pass: first try the raw name, then try Umlaut-restored version.

    // Remove "app" suffix if present: "spotify app" → "spotify"
    name = name.replaceAll(RegExp(r'\s+app\s*$'), '').trim();

    // Remove trailing punctuation
    name = name.replaceAll(RegExp(r'[.!?,;:]$'), '').trim();

    // Collapse whitespace
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }

  /// Try to resolve an app name to a package name.
  /// Attempts multiple normalization strategies.
  static String? resolvePackageName(String input) {
    final name = normalizeAppName(input);

    // Direct lookup
    if (_knownApps.containsKey(name)) {
      return _knownApps[name];
    }

    // Try Umlaut restoration: ae→ä, oe→ö, ue→ü
    final withUmlauts = _restoreUmlauts(name);
    if (_knownApps.containsKey(withUmlauts)) {
      return _knownApps[withUmlauts];
    }

    // Try Umlaut-to-ascii: ö→oe, ä→ae, ü→ue
    final withAscii = _umlautToAscii(name);
    if (_knownApps.containsKey(withAscii)) {
      return _knownApps[withAscii];
    }

    // Try without spaces
    final noSpaces = name.replaceAll(' ', '');
    if (_knownApps.containsKey(noSpaces)) {
      return _knownApps[noSpaces];
    }

    // If it looks like a package name (contains a dot), return as-is
    if (name.contains('.')) {
      return name;
    }

    return null;
  }

  /// Restore German Umlauts from ae/oe/ue patterns.
  /// Only restores when the pattern is likely an Umlaut (not in common words like "uber").
  static String _restoreUmlauts(String input) {
    var result = input;
    // Replace ae→ä, oe→ö, ue→ü — but be careful with common words
    // Simple heuristic: replace when followed by a consonant or at end of word
    result = result.replaceAllMapped(
      RegExp(r'ae(?=[bcdfghjklmnpqrstvwxyzß]|$)'),
      (m) => 'ä',
    );
    result = result.replaceAllMapped(
      RegExp(r'oe(?=[bcdfghjklmnpqrstvwxyzß]|$)'),
      (m) => 'ö',
    );
    result = result.replaceAllMapped(
      RegExp(r'ue(?=[bcdfghjklmnpqrstvwxyzß]|$)'),
      (m) => 'ü',
    );
    return result;
  }

  /// Convert German Umlauts to ASCII equivalents.
  static String _umlautToAscii(String input) {
    return input
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final rawApp = (parameters['app'] as String? ??
              parameters['app_name'] as String? ??
              parameters['name'] as String? ??
              '')
          .trim();
      if (rawApp.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine App angegeben',
          isError: true,
          displayText: 'Keine App angegeben',
        );
      }

      // Resolve to package name using normalization
      final packageName = resolvePackageName(rawApp) ?? rawApp.toLowerCase();

      var launched = await AndroidAppLauncherService.launchApp(packageName);
      if (!launched && !rawApp.contains('.')) {
        // If the static package map misses the user's installed app name, ask
        // Android to search launcher labels/packages semantically-ish by query.
        launched = await AndroidAppLauncherService.launchAppByQuery(rawApp);
      }
      if (!launched) {
        // App not found or not installed — report error, do NOT open Play Store.
        // Play Store should never be opened as a fallback for app-launch requests.
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'App "$rawApp" konnte nicht geoeffnet werden. Ist sie installiert? (Package: $packageName)',
          isError: true,
          displayText: 'App "$rawApp" nicht gefunden — ist sie installiert?',
        );
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'App geöffnet: $rawApp ($packageName)',
        displayText: '$rawApp geöffnet',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Konnte App nicht öffnen: $e',
        isError: true,
        displayText: 'Fehler beim Öffnen',
      );
    }
  }
}
