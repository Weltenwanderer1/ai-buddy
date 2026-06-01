import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for recording voice memos using the device microphone.
///
/// Uses a platform channel to control Android's MediaRecorder.
class VoiceRecorderService extends ChangeNotifier {
  static const _channel = MethodChannel('com.aibuddy.app/voice_recorder');

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  Duration? get currentDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Start recording a voice memo. Returns the file path where it will be saved.
  Future<String?> startRecording() async {
    if (_isRecording) {
      debugPrint('VoiceRecorderService: already recording');
      return null;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final memosDir = Directory('${dir.path}/voice_memos');
      if (!await memosDir.exists()) {
        await memosDir.create(recursive: true);
      }

      final id = const Uuid().v4().substring(0, 8);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final filePath = '${memosDir.path}/memo_${timestamp}_$id.m4a';

      final success = await _channel.invokeMethod('startRecording', {
        'outputPath': filePath,
      });

      if (success == true) {
        _isRecording = true;
        _currentRecordingPath = filePath;
        _recordingStartTime = DateTime.now();
        notifyListeners();
        debugPrint('VoiceRecorderService: started recording to $filePath');
        return filePath;
      } else {
        debugPrint('VoiceRecorderService: startRecording returned false');
        return null;
      }
    } catch (e) {
      debugPrint('VoiceRecorderService: startRecording error: $e');
      return null;
    }
  }

  /// Stop the current recording. Returns the file path of the recorded memo.
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('VoiceRecorderService: not recording');
      return null;
    }

    try {
      final success = await _channel.invokeMethod('stopRecording');
      final path = _currentRecordingPath;

      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      notifyListeners();

      if (success == true && path != null) {
        debugPrint('VoiceRecorderService: saved to $path');
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('VoiceRecorderService: stopRecording error: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      notifyListeners();
      return null;
    }
  }

  /// List all saved voice memos.
  Future<List<FileSystemEntity>> listMemos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final memosDir = Directory('${dir.path}/voice_memos');
      if (!await memosDir.exists()) return [];

      final files = await memosDir.list().toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // newest first
      return files;
    } catch (e) {
      debugPrint('VoiceRecorderService: listMemos error: $e');
      return [];
    }
  }

  /// Delete a voice memo by path.
  Future<bool> deleteMemo(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('VoiceRecorderService: deleteMemo error: $e');
      return false;
    }
  }
}


