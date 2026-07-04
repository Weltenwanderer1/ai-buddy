import 'package:flutter/material.dart';

/// Lightweight i18n system for AI-Buddy.
/// Map-based, no code generation, no arb files.
/// Add a language by adding a key to [translations] and a locale to [supportedLocales].
///
/// Usage:
///   final t = AppLocalizations.of(context);  // or AppLoc.t
///   Text(t.welcome_title)
///
/// In MaterialApp:
///   locale: settings.appLocale,
///   supportedLocales: AppLocalizations.supportedLocales,
///   localizationsDelegates: [
///     AppLocalizations.delegate,
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///     GlobalCupertinoLocalizations.delegate,
///   ],

typedef L10n = AppLocalizations;

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return loc ?? AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// Language metadata for the picker.
  static const languageInfo = <String, LangInfo>{
    'en': LangInfo('English', '🇬🇧', 'English'),
    'de': LangInfo('Deutsch', '🇩🇪', 'German'),
    'es': LangInfo('Español', '🇪🇸', 'Spanish'),
    'ja': LangInfo('日本語', '🇯🇵', 'Japanese'),
    'zh': LangInfo('中文', '🇨🇳', 'Mandarin'),
  };

  String get langCode => locale.languageCode;

  // ─── Keys ───
  String get welcome_title => _t('welcome_title');
  String get welcome_subtitle => _t('welcome_subtitle');
  String get welcome_language_section => _t('welcome_language_section');
  String get welcome_language_hint => _t('welcome_language_hint');
  String get welcome_config_section => _t('welcome_config_section');
  String get welcome_provider => _t('welcome_provider');
  String get welcome_api_key => _t('welcome_api_key');
  String get welcome_api_key_hint => _t('welcome_api_key_hint');
  String get welcome_model => _t('welcome_model');
  String get welcome_model_hint => _t('welcome_model_hint');
  String get welcome_buddy_name => _t('welcome_buddy_name');
  String get welcome_buddy_name_hint => _t('welcome_buddy_name_hint');
  String get welcome_skip => _t('welcome_skip');
  String get welcome_get_started => _t('welcome_get_started');
  String get welcome_step => _t('welcome_step');
  String get welcome_of => _t('welcome_of');
  String get welcome_next => _t('welcome_next');
  String get welcome_back => _t('welcome_back');
  String get welcome_finish => _t('welcome_finish');
  String get welcome_theme => _t('welcome_theme');
  String get welcome_theme_light => _t('welcome_theme_light');
  String get welcome_theme_dark => _t('welcome_theme_dark');
  String get welcome_theme_system => _t('welcome_theme_system');
  String get welcome_accent => _t('welcome_accent');
  String get welcome_optional => _t('welcome_optional');
  String get welcome_test_connection => _t('welcome_test_connection');
  String get welcome_test_success => _t('welcome_test_success');
  String get welcome_test_fail => _t('welcome_test_fail');
  String get welcome_testing => _t('welcome_testing');
  String get welcome_provider_ollama => _t('welcome_provider_ollama');
  String get welcome_provider_openrouter => _t('welcome_provider_openrouter');
  String get welcome_provider_skip => _t('welcome_provider_skip');
  String get welcome_done_title => _t('welcome_done_title');
  String get welcome_done_body => _t('welcome_done_body');
  String get welcome_done_action => _t('welcome_done_action');
  String get welcome_tts_section => _t('welcome_tts_section');
  String get welcome_tts_enable => _t('welcome_tts_enable');
  String get welcome_stt_enable => _t('welcome_stt_enable');

  // ─── Common ───
  String get common_cancel => _t('common_cancel');
  String get common_save => _t('common_save');
  String get common_done => _t('common_done');
  String get common_error => _t('common_error');

  String _t(String key) {
    final dict = translations[langCode] ?? translations['en']!;
    return dict[key] ?? translations['en']![key] ?? key;
  }
}

class LangInfo {
  final String label;
  final String flag;
  final String englishLabel;
  const LangInfo(this.label, this.flag, this.englishLabel);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ─── Translation Maps ───

const translations = <String, Map<String, String>>{
  // ═══════════════════════════════════════════
  // English (default)
  // ═══════════════════════════════════════════
  'en': {
    'welcome_title': 'Welcome to AI-Buddy',
    'welcome_subtitle': 'Your AI companion — let\'s get you set up.',
    'welcome_language_section': 'Choose Language',
    'welcome_language_hint': 'You can change this anytime in Settings.',
    'welcome_config_section': 'Quick Setup',
    'welcome_provider': 'AI Provider',
    'welcome_api_key': 'API Key',
    'welcome_api_key_hint': 'Your API key (stored securely on device)',
    'welcome_model': 'Model',
    'welcome_model_hint': 'e.g. kimi-k2:cloud, llama3.3:70b',
    'welcome_buddy_name': 'Buddy Name',
    'welcome_buddy_name_hint': 'What should your AI call itself?',
    'welcome_skip': 'Skip for now',
    'welcome_get_started': 'Get Started',
    'welcome_step': 'Step',
    'welcome_of': 'of',
    'welcome_next': 'Next',
    'welcome_back': 'Back',
    'welcome_finish': 'Finish',
    'welcome_theme': 'Appearance',
    'welcome_theme_light': 'Light',
    'welcome_theme_dark': 'Dark',
    'welcome_theme_system': 'System',
    'welcome_accent': 'Accent Color',
    'welcome_optional': 'Optional',
    'welcome_test_connection': 'Test Connection',
    'welcome_test_success': 'Connection successful!',
    'welcome_test_fail': 'Connection failed — check your settings.',
    'welcome_testing': 'Testing…',
    'welcome_provider_ollama': 'Ollama Cloud',
    'welcome_provider_openrouter': 'OpenRouter',
    'welcome_provider_skip': 'Configure later',
    'welcome_done_title': 'You\'re all set!',
    'welcome_done_body': 'AI-Buddy is ready to go. You can adjust everything in Settings later.',
    'welcome_done_action': 'Start chatting',
    'welcome_tts_section': 'Voice',
    'welcome_tts_enable': 'Enable text-to-speech',
    'welcome_stt_enable': 'Enable speech-to-text',
    'common_cancel': 'Cancel',
    'common_save': 'Save',
    'common_done': 'Done',
    'common_error': 'Error',
  },

  // ═══════════════════════════════════════════
  // Deutsch
  // ═══════════════════════════════════════════
  'de': {
    'welcome_title': 'Willkommen bei AI-Buddy',
    'welcome_subtitle': 'Dein KI-Companion — lass uns alles einrichten.',
    'welcome_language_section': 'Sprache wählen',
    'welcome_language_hint': 'Kann jederzeit in den Einstellungen geändert werden.',
    'welcome_config_section': 'Schnelleinrichtung',
    'welcome_provider': 'KI-Anbieter',
    'welcome_api_key': 'API-Schlüssel',
    'welcome_api_key_hint': 'Dein API-Schlüssel (sicher auf dem Gerät gespeichert)',
    'welcome_model': 'Modell',
    'welcome_model_hint': 'z.B. kimi-k2:cloud, llama3.3:70b',
    'welcome_buddy_name': 'Buddy-Name',
    'welcome_buddy_name_hint': 'Wie soll dein KI heissen?',
    'welcome_skip': 'Später konfigurieren',
    'welcome_get_started': 'Loslegen',
    'welcome_step': 'Schritt',
    'welcome_of': 'von',
    'welcome_next': 'Weiter',
    'welcome_back': 'Zurück',
    'welcome_finish': 'Fertig',
    'welcome_theme': 'Darstellung',
    'welcome_theme_light': 'Hell',
    'welcome_theme_dark': 'Dunkel',
    'welcome_theme_system': 'System',
    'welcome_accent': 'Akzentfarbe',
    'welcome_optional': 'Optional',
    'welcome_test_connection': 'Verbindung testen',
    'welcome_test_success': 'Verbindung erfolgreich!',
    'welcome_test_fail': 'Verbindung fehlgeschlagen — Einstellungen prüfen.',
    'welcome_testing': 'Teste…',
    'welcome_provider_ollama': 'Ollama Cloud',
    'welcome_provider_openrouter': 'OpenRouter',
    'welcome_provider_skip': 'Später konfigurieren',
    'welcome_done_title': 'Alles bereit!',
    'welcome_done_body': 'AI-Buddy ist startklar. Alles kann später in den Einstellungen angepasst werden.',
    'welcome_done_action': 'Chat starten',
    'welcome_tts_section': 'Stimme',
    'welcome_tts_enable': 'Sprachausgabe aktivieren',
    'welcome_stt_enable': 'Spracherkennung aktivieren',
    'common_cancel': 'Abbrechen',
    'common_save': 'Speichern',
    'common_done': 'Fertig',
    'common_error': 'Fehler',
  },

  // ═══════════════════════════════════════════
  // Español
  // ═══════════════════════════════════════════
  'es': {
    'welcome_title': 'Bienvenido a AI-Buddy',
    'welcome_subtitle': 'Tu companero de IA — vamos a configurarlo.',
    'welcome_language_section': 'Elegir idioma',
    'welcome_language_hint': 'Puedes cambiarlo cuando quieras en Ajustes.',
    'welcome_config_section': 'Configuración rápida',
    'welcome_provider': 'Proveedor de IA',
    'welcome_api_key': 'Clave API',
    'welcome_api_key_hint': 'Tu clave API (guardada de forma segura en el dispositivo)',
    'welcome_model': 'Modelo',
    'welcome_model_hint': 'ej. kimi-k2:cloud, llama3.3:70b',
    'welcome_buddy_name': 'Nombre del Buddy',
    'welcome_buddy_name_hint': '¿Cómo debería llamarse tu IA?',
    'welcome_skip': 'Configurar más tarde',
    'welcome_get_started': 'Empezar',
    'welcome_step': 'Paso',
    'welcome_of': 'de',
    'welcome_next': 'Siguiente',
    'welcome_back': 'Atrás',
    'welcome_finish': 'Finalizar',
    'welcome_theme': 'Apariencia',
    'welcome_theme_light': 'Claro',
    'welcome_theme_dark': 'Oscuro',
    'welcome_theme_system': 'Sistema',
    'welcome_accent': 'Color de acento',
    'welcome_optional': 'Opcional',
    'welcome_test_connection': 'Probar conexión',
    'welcome_test_success': '¡Conexión exitosa!',
    'welcome_test_fail': 'Conexión fallida — revisa tu configuración.',
    'welcome_testing': 'Probando…',
    'welcome_provider_ollama': 'Ollama Cloud',
    'welcome_provider_openrouter': 'OpenRouter',
    'welcome_provider_skip': 'Configurar más tarde',
    'welcome_done_title': '¡Todo listo!',
    'welcome_done_body': 'AI-Buddy está listo. Puedes ajustar todo en Ajustes más tarde.',
    'welcome_done_action': 'Empezar a chatear',
    'welcome_tts_section': 'Voz',
    'welcome_tts_enable': 'Activar texto a voz',
    'welcome_stt_enable': 'Activar voz a texto',
    'common_cancel': 'Cancelar',
    'common_save': 'Guardar',
    'common_done': 'Hecho',
    'common_error': 'Error',
  },

  // ═══════════════════════════════════════════
  // 日本語 (Japanese)
  // ═══════════════════════════════════════════
  'ja': {
    'welcome_title': 'AI-Buddyへようこそ',
    'welcome_subtitle': 'あなたのAIコンパニオン — セットアップしましょう。',
    'welcome_language_section': '言語を選択',
    'welcome_language_hint': '設定でいつでも変更できます。',
    'welcome_config_section': 'クイックセットアップ',
    'welcome_provider': 'AIプロバイダー',
    'welcome_api_key': 'APIキー',
    'welcome_api_key_hint': 'APIキー（デバイスに安全に保存）',
    'welcome_model': 'モデル',
    'welcome_model_hint': '例: kimi-k2:cloud, llama3.3:70b',
    'welcome_buddy_name': 'バディー名',
    'welcome_buddy_name_hint': 'AIの名前は何にしますか？',
    'welcome_skip': '後で設定',
    'welcome_get_started': '始める',
    'welcome_step': 'ステップ',
    'welcome_of': '/',
    'welcome_next': '次へ',
    'welcome_back': '戻る',
    'welcome_finish': '完了',
    'welcome_theme': '外観',
    'welcome_theme_light': 'ライト',
    'welcome_theme_dark': 'ダーク',
    'welcome_theme_system': 'システム',
    'welcome_accent': 'アクセントカラー',
    'welcome_optional': '任意',
    'welcome_test_connection': '接続テスト',
    'welcome_test_success': '接続成功！',
    'welcome_test_fail': '接続失敗 — 設定を確認してください。',
    'welcome_testing': 'テスト中…',
    'welcome_provider_ollama': 'Ollama Cloud',
    'welcome_provider_openrouter': 'OpenRouter',
    'welcome_provider_skip': '後で設定',
    'welcome_done_title': '準備完了！',
    'welcome_done_body': 'AI-Buddyの準備ができました。設定で後から調整できます。',
    'welcome_done_action': 'チャットを始める',
    'welcome_tts_section': '音声',
    'welcome_tts_enable': 'テキスト読み上げを有効化',
    'welcome_stt_enable': '音声認識を有効化',
    'common_cancel': 'キャンセル',
    'common_save': '保存',
    'common_done': '完了',
    'common_error': 'エラー',
  },

  // ═══════════════════════════════════════════
  // 中文 (Mandarin Chinese)
  // ═══════════════════════════════════════════
  'zh': {
    'welcome_title': '欢迎使用 AI-Buddy',
    'welcome_subtitle': '你的AI伙伴 — 让我们开始设置吧。',
    'welcome_language_section': '选择语言',
    'welcome_language_hint': '可以随时在设置中更改。',
    'welcome_config_section': '快速设置',
    'welcome_provider': 'AI提供商',
    'welcome_api_key': 'API密钥',
    'welcome_api_key_hint': '你的API密钥（安全存储在设备上）',
    'welcome_model': '模型',
    'welcome_model_hint': '例如 kimi-k2:cloud, llama3.3:70b',
    'welcome_buddy_name': '伙伴名称',
    'welcome_buddy_name_hint': '你的AI叫什么名字？',
    'welcome_skip': '稍后配置',
    'welcome_get_started': '开始',
    'welcome_step': '第',
    'welcome_of': '步，共',
    'welcome_next': '下一步',
    'welcome_back': '返回',
    'welcome_finish': '完成',
    'welcome_theme': '外观',
    'welcome_theme_light': '浅色',
    'welcome_theme_dark': '深色',
    'welcome_theme_system': '跟随系统',
    'welcome_accent': '强调色',
    'welcome_optional': '可选',
    'welcome_test_connection': '测试连接',
    'welcome_test_success': '连接成功！',
    'welcome_test_fail': '连接失败 — 请检查设置。',
    'welcome_testing': '测试中…',
    'welcome_provider_ollama': 'Ollama Cloud',
    'welcome_provider_openrouter': 'OpenRouter',
    'welcome_provider_skip': '稍后配置',
    'welcome_done_title': '一切就绪！',
    'welcome_done_body': 'AI-Buddy 已准备就绪。稍后可在设置中调整所有内容。',
    'welcome_done_action': '开始聊天',
    'welcome_tts_section': '语音',
    'welcome_tts_enable': '启用文字转语音',
    'welcome_stt_enable': '启用语音转文字',
    'common_cancel': '取消',
    'common_save': '保存',
    'common_done': '完成',
    'common_error': '错误',
  },
};