import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Offline-capable speech recognition service using Android's SpeechRecognizer.
///
/// Uses a platform channel to access Android's built-in SpeechRecognizer
/// which can work offline if the user has downloaded language packs.
/// Falls back to the standard speech_to_text (cloud) if offline is unavailable.
class OfflineSttService {
  static const _channel = MethodChannel('com.aibuddy.app/offline_stt');

  bool _isListening = false;
  bool _offlineAvailable = false;

  bool get isListening => _isListening;
  bool get offlineAvailable => _offlineAvailable;

  /// Check if offline speech recognition is available.
  /// Requires the user to have downloaded offline language packs
  /// in Android Settings > Languages > Offline speech recognition.
  Future<bool> checkOfflineAvailability() async {
    try {
      final available = await _channel.invokeMethod('isOfflineAvailable');
      _offlineAvailable = available == true;
      debugPrint('OfflineSttService: offline available = $_offlineAvailable');
      return _offlineAvailable;
    } catch (e) {
      debugPrint('OfflineSttService: checkOffline error: $e');
      _offlineAvailable = false;
      return false;
    }
  }

  /// Start listening with offline preference.
  /// [preferOffline] — if true, tries offline first; if false, uses cloud.
  /// [localeId] — language code, e.g. "de_DE", "en_US".
  Future<String?> startListening({
    bool preferOffline = true,
    String localeId = 'de_DE',
  }) async {
    if (_isListening) {
      debugPrint('OfflineSttService: already listening');
      return null;
    }

    _isListening = true;

    try {
      final result = await _channel.invokeMethod('startListening', {
        'preferOffline': preferOffline,
        'locale': localeId,
      });

      if (result is String && result.isNotEmpty) {
        _isListening = false;
        return result;
      }

      _isListening = false;
      return null;
    } on PlatformException catch (e) {
      debugPrint('OfflineSttService: PlatformException: ${e.message}');
      _isListening = false;

      // If offline failed, try online
      if (preferOffline && e.code == 'OFFLINE_NOT_AVAILABLE') {
        debugPrint('OfflineSttService: falling back to online');
        return startListening(preferOffline: false, localeId: localeId);
      }
      return null;
    } catch (e) {
      debugPrint('OfflineSttService: error: $e');
      _isListening = false;
      return null;
    }
  }

  /// Stop listening.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      debugPrint('OfflineSttService: stop error: $e');
    }
    _isListening = false;
  }

  /// Prompt the user to download offline language packs.
  Future<void> promptDownloadOfflineLanguage() async {
    try {
      await _channel.invokeMethod('downloadOfflineLanguage');
    } catch (e) {
      debugPrint('OfflineSttService: download prompt error: $e');
    }
  }
}
