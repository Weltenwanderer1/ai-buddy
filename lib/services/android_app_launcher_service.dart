import 'dart:io';

import 'package:flutter/services.dart';

/// Small Android-only bridge for launching another app's real launcher activity.
///
/// android_intent_plus with only MAIN/LAUNCHER + package can land in the app
/// drawer on some launchers. The native side uses PackageManager
/// getLaunchIntentForPackage(), which resolves the concrete launcher activity.
class AndroidAppLauncherService {
  static const MethodChannel _channel = MethodChannel('ai_buddy/app_launcher');

  static Future<bool> launchApp(String packageName) async {
    if (!Platform.isAndroid) return true;
    final launched = await _channel.invokeMethod<bool>('launchApp', {
      'packageName': packageName,
    });
    return launched ?? false;
  }

  static Future<bool> launchAppByQuery(String query) async {
    if (!Platform.isAndroid) return true;
    final launched = await _channel.invokeMethod<bool>('launchAppByQuery', {
      'query': query,
    });
    return launched ?? false;
  }

  /// Shares text directly to a specific app via ACTION_SEND.
  /// Returns true if the share intent was successfully dispatched.
  static Future<bool> shareToApp(String packageName, String text) async {
    if (!Platform.isAndroid) return true;
    final shared = await _channel.invokeMethod<bool>('shareToApp', {
      'packageName': packageName,
      'text': text,
    });
    return shared ?? false;
  }
}
