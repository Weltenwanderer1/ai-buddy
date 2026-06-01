import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to control device volume via Android platform channel.
class VolumeService {
  static const _channel = MethodChannel('com.aibuddy.app/volume');

  /// Set volume for a specific stream (0.0 - 1.0).
  /// Stream types: 'music', 'alarm', 'notification', 'system', 'ring', 'voice_call'
  Future<bool> setVolume(String stream, double level) async {
    try {
      final result = await _channel.invokeMethod('setVolume', {
        'stream': _mapStream(stream),
        'level': level.clamp(0.0, 1.0),
      });
      return result == true;
    } catch (e) {
      debugPrint('VolumeService.setVolume error: $e');
      return false;
    }
  }

  /// Get current volume for a specific stream (0.0 - 1.0).
  Future<double?> getVolume(String stream) async {
    try {
      final result = await _channel.invokeMethod('getVolume', {
        'stream': _mapStream(stream),
      });
      if (result is double) return result;
      if (result is int) return result / 100.0;
      return null;
    } catch (e) {
      debugPrint('VolumeService.getVolume error: $e');
      return null;
    }
  }

  /// Mute or unmute the device.
  Future<bool> setMute(bool mute) async {
    try {
      final result = await _channel.invokeMethod('setMute', {
        'mute': mute,
      });
      return result == true;
    } catch (e) {
      debugPrint('VolumeService.setMute error: $e');
      return false;
    }
  }

  /// Map user-friendly stream names to Android stream constants.
  String _mapStream(String stream) {
    switch (stream.toLowerCase()) {
      case 'media':
      case 'music':
        return 'music';
      case 'alarm':
        return 'alarm';
      case 'notification':
      case 'notify':
        return 'notification';
      case 'system':
        return 'system';
      case 'ring':
      case 'ringer':
        return 'ring';
      case 'call':
      case 'voice_call':
        return 'voice_call';
      default:
        return 'music';
    }
  }
}
