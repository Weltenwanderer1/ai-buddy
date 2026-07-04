import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

/// Persists chat messages to disk so they survive app restarts.
class ChatHistoryService extends ChangeNotifier {
  static const _maxMessages = 200;
  List<ChatMessage> _messages = [];
  late File _file;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/chat_history.json');
    await _load();
  }

  Future<void> add(ChatMessage message) async {
    _messages.add(message);
    _trim();
    notifyListeners();
    await _save();
  }

  Future<void> addAll(List<ChatMessage> messages) async {
    _messages.addAll(messages);
    _trim();
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _messages.clear();
    notifyListeners();
    await _save();
  }

  void _trim() {
    if (_messages.length > _maxMessages) {
      _messages = _messages.sublist(_messages.length - _maxMessages);
    }
  }

  Future<void> _load() async {
    if (!await _file.exists()) return;
    try {
      final data = jsonDecode(await _file.readAsString()) as List;
      _messages = data
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Corrupted file — start fresh
      _messages = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  /// Export all messages as a JSON-serializable list.
  Map<String, dynamic> exportData() => {
    'messages': _messages.map((m) => m.toJson()).toList(),
  };

  /// Import messages from a JSON map (as produced by [exportData]).
  Future<void> importData(Map<String, dynamic> data) async {
    final msgs = (data['messages'] as List?)
            ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    _messages = msgs;
    _trim();
    notifyListeners();
    await _save();
  }
}
