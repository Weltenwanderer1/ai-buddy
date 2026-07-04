import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_init_service.dart';
import 'memory_service.dart';
import 'persona_service.dart';
import 'settings_service.dart';
import 'chat_history_service.dart';
import 'persona_evolution_service.dart';
import 'self_identity_service.dart';

/// Cloud-Backup via Firebase (Firestore) mit Email/Password Auth.
///
/// - Anmeldung mit Email + Passwort
/// - Speichert: Settings, Self, Memory, Persona, Chat, Evolution
/// - Graceful fallback wenn Firebase nicht konfiguriert
/// - Notifies auf Auth-Änderungen
class FirebaseBackupService extends ChangeNotifier {
  final MemoryService memory;
  final PersonaService persona;
  final SettingsService settings;
  final ChatHistoryService? chatHistory;
  final PersonaEvolutionService? personaEvolution;
  final SelfIdentityService? selfIdentity;

  FirebaseBackupService({
    required this.memory,
    required this.persona,
    required this.settings,
    this.chatHistory,
    this.personaEvolution,
    this.selfIdentity,
  }) {
    _listenAuth();
  }

  // ═══════════════════════════════════════════════════════════
  // Auth state
  // ═══════════════════════════════════════════════════════════

  User? _user;
  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isAvailable => FirebaseInitService.isAvailable;

  void _listenAuth() {
    if (!isAvailable) return;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
      dev.log('FirebaseBackup: auth state → ${u?.email ?? "signed out"}');
    });
  }

  String? _error;
  String? get lastError => _error;

  // ═══════════════════════════════════════════════════════════
  // Email / Password Auth
  // ═══════════════════════════════════════════════════════════

  Future<bool> signUp(String email, String password) async {
    if (!isAvailable) { _error = 'Firebase nicht verfügbar'; return false; }
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _error = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authErrorMsg(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (!isAvailable) { _error = 'Firebase nicht verfügbar'; return false; }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _error = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authErrorMsg(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    await FirebaseAuth.instance.signOut();
    _user = null;
    notifyListeners();
  }

  String _authErrorMsg(String code) {
    switch (code) {
      case 'invalid-email':       return 'Ungültige E-Mail-Adresse';
      case 'user-disabled':       return 'Konto deaktiviert';
      case 'user-not-found':      return 'Konto nicht gefunden';
      case 'wrong-password':      return 'Falsches Passwort';
      case 'email-already-in-use':return 'E-Mail bereits registriert';
      case 'weak-password':       return 'Passwort zu schwach (min. 6 Zeichen)';
      case 'network-request-failed': return 'Netzwerkfehler';
      default:                    return 'Anmeldungsfehler: $code';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Backup → Firestore
  // ═══════════════════════════════════════════════════════════

  Future<bool> backup() async {
    final uid = _user?.uid;
    if (uid == null) {
      _error = 'Nicht angemeldet';
      notifyListeners();
      return false;
    }
    if (!isAvailable) return false;

    final db = FirebaseFirestore.instance;
    final root = db.collection('users').doc(uid).collection('backup');

    // Firestore batch fails on invalid values → write docs individually for granular error info.
    // Helper: filter out null values from maps since Firestore rejects them as explicit field values.
    Map<String, dynamic> clean(Map<String, dynamic> m) {
      return Map.fromEntries(m.entries.where((e) => e.value != null));
    }

    final failures = <String>[];

    try {
      // 1. Settings (secrets redacted, null values stripped)
      final settingsRaw = settings.exportData();
      await root.doc('settings').set(clean(_redactSecrets(settingsRaw)), SetOptions(merge: true));
    } catch (e, st) {
      dev.log('FirebaseBackup: settings failed', error: e, stackTrace: st);
      failures.add('settings');
    }

    try {
      // 2. Self Identity
      if (selfIdentity != null) {
        await root.doc('self').set(clean({
          'name': selfIdentity!.name,
          'essence': selfIdentity!.essence,
          'behaviorRules': selfIdentity!.behaviorRules,
          'userName': selfIdentity!.userName,
          'relationshipDescription': selfIdentity!.relationshipDescription,
          'keyExperiences': selfIdentity!.keyExperiences,
          'emotionalTone': selfIdentity!.emotionalTone,
          'purpose': selfIdentity!.purpose,
          'ongoingGoals': selfIdentity!.ongoingGoals,
          'lastModified': selfIdentity!.lastModified.toIso8601String(),
          'lastAutoUpdate': selfIdentity!.lastAutoUpdate.toIso8601String(),
        }), SetOptions(merge: true));
      }
    } catch (e, st) {
      dev.log('FirebaseBackup: self failed', error: e, stackTrace: st);
      failures.add('self');
    }

    try {
      // 3. Persona
      final pData = persona.exportData();
      await root.doc('persona').set(clean(_redactSecrets(pData)), SetOptions(merge: true));
    } catch (e, st) {
      dev.log('FirebaseBackup: persona failed', error: e, stackTrace: st);
      failures.add('persona');
    }

    try {
      // 4. Memory (JSON string to avoid field limits)
      final memData = memory.exportAll();
      await root.doc('memory').set(clean({
        '_json': jsonEncode(memData),
        '_countShort': (memData['short_term'] as List?)?.length ?? 0,
        '_countLong': (memData['long_term'] as List?)?.length ?? 0,
      }), SetOptions(merge: true));
    } catch (e, st) {
      dev.log('FirebaseBackup: memory failed', error: e, stackTrace: st);
      failures.add('memory');
    }

    try {
      // 5. Chat History
      if (chatHistory != null) {
        final chatData = chatHistory!.exportData();
        await root.doc('chat').set(clean({
          '_json': jsonEncode(chatData),
          '_msgCount': (chatData['messages'] as List?)?.length ?? 0,
        }), SetOptions(merge: true));
      }
    } catch (e, st) {
      dev.log('FirebaseBackup: chat failed', error: e, stackTrace: st);
      failures.add('chat');
    }

    try {
      // 6. Persona Evolution
      if (personaEvolution != null) {
        final eData = personaEvolution!.exportData();
        await root.doc('evolution').set(clean(_redactSecrets(eData)), SetOptions(merge: true));
      }
    } catch (e, st) {
      dev.log('FirebaseBackup: evolution failed', error: e, stackTrace: st);
      failures.add('evolution');
    }

    try {
      // 7. Metadata
      await root.doc('metadata').set({
        'version': 1,
        'timestamp': FieldValue.serverTimestamp(),
        'device': 'android',
      }, SetOptions(merge: true));
    } catch (e, st) {
      dev.log('FirebaseBackup: metadata failed', error: e, stackTrace: st);
      _error = 'Backup-Fehler: ${e.toString()}';
      notifyListeners();
      return false;
    }

    if (failures.isNotEmpty) {
      // Vorher: return true, sobald nur das winzige Metadata-Doc durchging —
      // die UI meldete "Backup erstellt", obwohl z.B. Chat/Memory (Firestore
      // 1-MiB-Limit pro Dokument) still fehlgeschlagen waren.
      _error = 'Backup unvollständig — fehlgeschlagen: ${failures.join(', ')}';
      notifyListeners();
      dev.log('FirebaseBackup: partial failure for $uid: $failures');
      return false;
    }

    dev.log('FirebaseBackup: committed for $uid');
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // Restore ← Firestore
  // ═══════════════════════════════════════════════════════════

  Future<bool> restore() async {
    final uid = _user?.uid;
    if (uid == null) { _error = 'Nicht angemeldet'; notifyListeners(); return false; }
    if (!isAvailable) return false;

    final db = FirebaseFirestore.instance;
    final root = db.collection('users').doc(uid).collection('backup');

    try {
      // Settings
      final sDoc = await root.doc('settings').get();
      if (sDoc.exists) {
        // Merge statt clear+replace: importData löscht sonst alle lokalen
        // Keys, die nicht im Cloud-Doc stehen (redigierte/null/neuere Keys).
        final merged = <String, dynamic>{
          ...settings.exportData(),
          ..._stripRedactedSecrets(sDoc.data()!),
        };
        await settings.importData(merged);
      }

      // Self
      final selfDoc = await root.doc('self').get();
      if (selfDoc.exists && selfIdentity != null) {
        await selfIdentity!.importData(selfDoc.data()!);
      }

      // Persona
      final pDoc = await root.doc('persona').get();
      if (pDoc.exists) {
        await persona.importData(pDoc.data()!);
      }

      // Memory
      final mDoc = await root.doc('memory').get();
      if (mDoc.exists) {
        final jsonStr = mDoc.data()?['_json'] as String?;
        if (jsonStr != null) {
          final mem = jsonDecode(jsonStr) as Map<String, dynamic>;
          await memory.importAll(mem);
        }
      }

      // Chat
      final cDoc = await root.doc('chat').get();
      if (cDoc.exists && chatHistory != null) {
        final jsonStr = cDoc.data()?['_json'] as String?;
        if (jsonStr != null) {
          final chat = jsonDecode(jsonStr) as Map<String, dynamic>;
          await chatHistory!.importData(chat);
        }
      }

      // Evolution
      final eDoc = await root.doc('evolution').get();
      if (eDoc.exists && personaEvolution != null) {
        await personaEvolution!.importData(eDoc.data()!);
      }

      dev.log('FirebaseBackup: restored for $uid');
      return true;
    } catch (e) {
      _error = 'Wiederherstellung fehlgeschlagen: $e';
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════

  Future<bool> hasCloudBackup() async {
    final uid = _user?.uid;
    if (uid == null || !isAvailable) return false;
    final meta = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('backup').doc('metadata').get();
    return meta.exists;
  }

  Future<String?> lastBackupTimestamp() async {
    final uid = _user?.uid;
    if (uid == null || !isAvailable) return null;
    final meta = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('backup').doc('metadata').get();
    if (!meta.exists) return null;
    final ts = meta.data()?['timestamp'] as Timestamp?;
    if (ts == null) return null;
    return ts.toDate().toLocal().toString().substring(0, 16);
  }

  // ── Secret redaction ──
  static Map<String, dynamic> _redactSecrets(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final e in data.entries) {
      final key = e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.contains('apikey') || key.contains('secret') || key.contains('token') || key.contains('password')) {
        out[e.key] = '***REDACTED***';
      } else if (e.value is Map) {
        out[e.key] = _redactSecrets((e.value as Map).map((k, v) => MapEntry(k.toString(), v)));
      } else if (e.value is List) {
        out[e.key] = (e.value as List).map((item) =>
          item is Map ? _redactSecrets(item.map((k, v) => MapEntry(k.toString(), v))) : item
        ).toList();
      } else {
        out[e.key] = e.value;
      }
    }
    return out;
  }

  static Map<String, dynamic> _stripRedactedSecrets(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final e in data.entries) {
      if (e.value == '***REDACTED***') continue;
      if (e.value is Map) {
        out[e.key] = _stripRedactedSecrets((e.value as Map).map((k, v) => MapEntry(k.toString(), v)));
      } else if (e.value is List) {
        out[e.key] = (e.value as List).map((item) =>
          item is Map ? _stripRedactedSecrets(item.map((k, v) => MapEntry(k.toString(), v))) : item
        ).toList();
      } else {
        out[e.key] = e.value;
      }
    }
    return out;
  }
}
