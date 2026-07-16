import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'stt_service.dart';
import 'buddy_notes_service.dart';

/// Handles voice recording → transcription → saving as a buddy note.
class DictationService {
  final SttService _stt;
  final BuddyNotesService _notes;

  bool _isRecording = false;

  DictationService(this._stt, this._notes);

  bool get isRecording => _isRecording;

  /// Record a short voice memo, transcribe it, and append to BuddyNotes.
  /// Returns the transcribed text, or null if cancelled/empty.
  Future<String?> recordAndSave({String locale = 'de_DE'}) async {
    if (_isRecording) return null;
    _isRecording = true;

    try {
      final available = await _stt.init();
      if (!available) {
        debugPrint('DictationService: STT not available');
        return null;
      }

      // Device-STT listen for up to 30 seconds
      final text = await _stt.listenonce(
        localeId: locale,
      );

      if (text == null || text.trim().isEmpty) {
        debugPrint('DictationService: no speech detected');
        return null;
      }

      final cleaned = text.trim();
      await _notes.append('🎙️ $cleaned');
      return cleaned;
    } finally {
      _isRecording = false;
    }
  }
}
