// Die Getter spiegeln bewusst die snake_case-Übersetzungs-Keys wider —
// ein i18n-Wörterbuch, keine normalen Bezeichner.
// ignore_for_file: non_constant_identifier_names
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

  // ─── Welcome ───
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
  String get welcome_embedding_model => _t('welcome_embedding_model');
  String get welcome_embedding_model_hint => _t('welcome_embedding_model_hint');
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
  String get common_delete => _t('common_delete');
  String get common_confirm => _t('common_confirm');
  String get common_test => _t('common_test');
  String get common_download => _t('common_download');
  String get common_load => _t('common_load');
  String get common_restore => _t('common_restore');
  String get common_ok => _t('common_ok');
  String get common_back => _t('common_back');
  String get common_next => _t('common_next');
  String get common_edit => _t('common_edit');
  String get common_expand => _t('common_expand');
  String get common_collapse => _t('common_collapse');
  String get common_default => _t('common_default');

  // ─── Chat ───
  String get chat_hint_message => _t('chat_hint_message');
  String get chat_error_timeout => _t('chat_error_timeout');
  String get chat_error_generic => _t('chat_error_generic');
  String get chat_selected_count => _t('chat_selected_count');
  String get chat_copied_count => _t('chat_copied_count');
  String get chat_initial_prompt => _t('chat_initial_prompt');

  // ─── STT ───
  String get stt_not_available => _t('stt_not_available');
  String get stt_permission_needed => _t('stt_permission_needed');

  // ─── Navigation ───
  String get navigation_destination => _t('navigation_destination');
  String get navigation_steps => _t('navigation_steps');
  String get navigation_show_on_map => _t('navigation_show_on_map');
  String get map_label => _t('map_label');
  String get location_label => _t('location_label');

  // ─── Data (missing bodies) ───
  String get data_chat_delete_body => _t('data_chat_delete_body');
  String get data_memories_delete_body => _t('data_memories_delete_body');

  // ─── Settings Tabs ───
  String get settings_title => _t('settings_title');
  String get settings_tab_general => _t('settings_tab_general');
  String get settings_tab_appearance => _t('settings_tab_appearance');
  String get settings_tab_buddy => _t('settings_tab_buddy');
  String get settings_tab_tools => _t('settings_tab_tools');
  String get settings_tab_config => _t('settings_tab_config');
  String get settings_tab_data => _t('settings_tab_data');
  String get settings_tab_background => _t('settings_tab_background');
  String get settings_tab_about => _t('settings_tab_about');

  // ─── Appearance ───
  String get appearance_language => _t('appearance_language');
  String get appearance_accent_color => _t('appearance_accent_color');
  String get appearance_theme_light => _t('appearance_theme_light');
  String get appearance_theme_dark => _t('appearance_theme_dark');
  String get appearance_theme_system => _t('appearance_theme_system');

  // ─── Buddy ───
  String get buddy_name => _t('buddy_name');
  String get buddy_name_hint => _t('buddy_name_hint');
  String get buddy_name_saved => _t('buddy_name_saved');
  String get buddy_persona_edit => _t('buddy_persona_edit');
  String get buddy_persona_desc => _t('buddy_persona_desc');
  String get buddy_self_identity => _t('buddy_self_identity');
  String get buddy_evolution => _t('buddy_evolution');
  String get buddy_evolution_desc => _t('buddy_evolution_desc');
  String get buddy_evolution_traits => _t('buddy_evolution_traits');
  String get buddy_evolution_empty => _t('buddy_evolution_empty');
  String get buddy_memories => _t('buddy_memories');
  String get buddy_offline_maps => _t('buddy_offline_maps');
  String get buddy_offline_maps_desc => _t('buddy_offline_maps_desc');
  String get buddy_notes => _t('buddy_notes');
  String get buddy_notes_desc => _t('buddy_notes_desc');
  String get buddy_capabilities => _t('buddy_capabilities');
  String get buddy_capabilities_desc => _t('buddy_capabilities_desc');

  // ─── Tools ───
  String get tools_section => _t('tools_section');
  String get tools_desc => _t('tools_desc');

  // ─── Config ───
  String get config_provider => _t('config_provider');
  String get config_api_key => _t('config_api_key');
  String get config_model => _t('config_model');
  String get config_model_hint => _t('config_model_hint');
  String get config_base_url => _t('config_base_url');
  String get config_base_url_ollama => _t('config_base_url_ollama');
  String get config_base_url_openrouter => _t('config_base_url_openrouter');
  String get config_base_url_openai => _t('config_base_url_openai');
  String get config_email => _t('config_email');
  String get config_email_address => _t('config_email_address');
  String get config_email_password => _t('config_email_password');
  String get config_email_server => _t('config_email_server');
  String get config_email_port => _t('config_email_port');
  String get config_email_saved => _t('config_email_saved');
  String get config_embedding => _t('config_embedding');
  String get config_embedding_model => _t('config_embedding_model');
  String get config_embedding_model_ollama => _t('config_embedding_model_ollama');
  String get config_embedding_model_openai => _t('config_embedding_model_openai');
  String get config_embedding_model_openrouter => _t('config_embedding_model_openrouter');
  String get config_embedding_saved => _t('config_embedding_saved');
  String get config_embedding_ok => _t('config_embedding_ok');
  String get config_embedding_error => _t('config_embedding_error');
  String get config_embedding_testing => _t('config_embedding_testing');
  String get config_embedding_no_result => _t('config_embedding_no_result');
  String get config_tts => _t('config_tts');
  String get config_tts_engine => _t('config_tts_engine');
  String get config_tts_speed => _t('config_tts_speed');
  String get config_tts_device_desc => _t('config_tts_device_desc');
  String get config_tts_saved => _t('config_tts_saved');
  String get config_piper_voices => _t('config_piper_voices');
  String get config_piper_language => _t('config_piper_language');
  String get config_piper_all_languages => _t('config_piper_all_languages');
  String get config_piper_downloaded => _t('config_piper_downloaded');
  String get config_piper_not_downloaded => _t('config_piper_not_downloaded');
  String get config_piper_downloading => _t('config_piper_downloading');
  String get config_piper_active => _t('config_piper_active');
  String get config_proactivity => _t('config_proactivity');
  String get config_proactivity_off => _t('config_proactivity_off');
  String get config_proactivity_low => _t('config_proactivity_low');
  String get config_proactivity_normal => _t('config_proactivity_normal');
  String get config_proactivity_high => _t('config_proactivity_high');
  String get config_proactivity_off_desc => _t('config_proactivity_off_desc');
  String get config_proactivity_low_desc => _t('config_proactivity_low_desc');
  String get config_proactivity_normal_desc => _t('config_proactivity_normal_desc');
  String get config_proactivity_high_desc => _t('config_proactivity_high_desc');
  String get config_saved => _t('config_saved');
  String get config_testing => _t('config_testing');
  String get config_test_ok => _t('config_test_ok');
  String get config_test_fail => _t('config_test_fail');
  String get config_test_message => _t('config_test_message');
  String get config_test_hello => _t('config_test_hello');
  String get config_fallback => _t('config_fallback');
  String get config_model_id => _t('config_model_id');
  String get config_custom_id => _t('config_custom_id');
  String get config_custom_id_hint => _t('config_custom_id_hint');

  // ─── Data ───
  String get data_backup => _t('data_backup');
  String get data_backup_create => _t('data_backup_create');
  String get data_backup_created => _t('data_backup_created');
  String get data_backup_restore => _t('data_backup_restore');
  String get data_backup_restore_confirm => _t('data_backup_restore_confirm');
  String get data_backup_restored => _t('data_backup_restored');
  String get data_backup_overwrite_warning => _t('data_backup_overwrite_warning');
  String get data_chat_delete => _t('data_chat_delete');
  String get data_chat_delete_confirm => _t('data_chat_delete_confirm');
  String get data_chat_deleted => _t('data_chat_deleted');
  String get data_memories_delete => _t('data_memories_delete');
  String get data_memories_delete_confirm => _t('data_memories_delete_confirm');
  String get data_memories_deleted => _t('data_memories_deleted');
  String get data_reset => _t('data_reset');
  String get data_reset_confirm => _t('data_reset_confirm');
  String get data_reset_warning => _t('data_reset_warning');
  String get data_reset_done => _t('data_reset_done');

  // ─── Background Tasks ───
  String get bg_tasks_title => _t('bg_tasks_title');
  String get bg_tasks_run_now => _t('bg_tasks_run_now');

  // ─── About ───
  String get about_title => _t('about_title');
  String get about_version => _t('about_version');

  // ─── Chat Screen ───
  String get chat_you => _t('chat_you');
  String get chat_copied => _t('chat_copied');
  String get chat_attachment => _t('chat_attachment');
  String get chat_take_photo => _t('chat_take_photo');
  String get chat_from_gallery => _t('chat_from_gallery');
  String get chat_osm_navigation => _t('chat_osm_navigation');
  String get chat_voice_ready => _t('chat_voice_ready');
  String get chat_voice_listening => _t('chat_voice_listening');
  String get chat_voice_thinking => _t('chat_voice_thinking');
  String get chat_voice_speaking => _t('chat_voice_speaking');
  String get chat_voice_error => _t('chat_voice_error');
  String get chat_stop => _t('chat_stop');

  // ─── Time ───
  String get time_just_now => _t('time_just_now');
  String get time_minutes_ago => _t('time_minutes_ago');
  String get time_hours_ago => _t('time_hours_ago');
  String get time_days_ago => _t('time_days_ago');

  // ─── Speed ───
  String get speed_slow => _t('speed_slow');
  String get speed_fast => _t('speed_fast');

  // ─── Memory ───
  String get memory_core_long_short => _t('memory_core_long_short');
  String get memory_all_learn => _t('memory_all_learn');

  // ─── Proactivity ───
  String get proactivity_time_place_routines => _t('proactivity_time_place_routines');
  String get proactivity_urgent_only => _t('proactivity_urgent_only');
  String get proactivity_none => _t('proactivity_none');

  // ─── Model names (keep as-is, these are proper names) ───
  // These are technical identifiers, not translated
  String get model_claude_haiku => _t('model_claude_haiku');
  String get model_claude_sonnet => _t('model_claude_sonnet');
  String get model_claude_opus => _t('model_claude_opus');
  String get model_claude_sonnet4 => _t('model_claude_sonnet4');
  String get model_gpt4o => _t('model_gpt4o');
  String get model_gpt4o_mini => _t('model_gpt4o_mini');
  String get model_gpt41 => _t('model_gpt41');
  String get model_o4_mini => _t('model_o4_mini');
  String get model_gemini_flash => _t('model_gemini_flash');
  String get model_deepseek_v4 => _t('model_deepseek_v4');
  String get model_deepseek_flash => _t('model_deepseek_flash');
  String get model_kimi_k2 => _t('model_kimi_k2');


  String get bg_tasks_every_minutes => _t('bg_tasks_every_minutes');
  String get bg_tasks_last_run => _t('bg_tasks_last_run');
  String get data_reset_desc => _t('data_reset_desc');
  String get config_openrouter_api_key => _t('config_openrouter_api_key');

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
    // Welcome
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
    'welcome_embedding_model': 'Embedding Model',
    'welcome_embedding_model_hint': 'e.g. nomic-embed-text',
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

    // Common
    'common_cancel': 'Cancel',
    'common_save': 'Save',
    'common_done': 'Done',
    'common_error': 'Error',
    'common_delete': 'Delete',
    'common_confirm': 'Confirm',
    'common_test': 'Test',
    'common_download': 'Download',
    'common_load': 'Load',
    'common_restore': 'Restore',
    'common_ok': 'OK',
    'common_back': 'Back',
    'common_next': 'Next',
    'common_edit': 'Edit',
    'common_expand': 'Expand to edit',
    'common_collapse': 'Collapse to edit',
    'common_default': 'Default',

    // Chat
    'chat_hint_message': 'Message',
    'chat_error_timeout': 'The request took too long. Please try again.',
    'chat_error_generic': 'An error occurred. Please try again.',
    'chat_selected_count': '{count} selected',
    'chat_copied_count': '{count} message(s) copied',
    'chat_initial_prompt': 'What can you do for me? What tools and features do you have?',

    // STT
    'stt_not_available': 'Speech recognition not available',
    'stt_permission_needed': 'Microphone permission required',

    // Navigation
    'navigation_destination': 'Destination',
    'navigation_steps': '{count} steps',
    'navigation_show_on_map': 'Show on map',
    'map_label': 'Map',
    'location_label': 'Location',

    // Data bodies
    'data_chat_delete_body': 'All messages will be permanently deleted.',
    'data_memories_delete_body': 'All stored memories will be deleted.',

    // Settings Tabs
    'settings_title': 'Settings',
    'settings_tab_general': 'General',
    'settings_tab_appearance': 'Appearance',
    'settings_tab_buddy': 'Buddy',
    'settings_tab_tools': 'Tools',
    'settings_tab_config': 'Configuration',
    'settings_tab_data': 'Data',
    'settings_tab_background': 'Background Tasks',
    'settings_tab_about': 'About',

    // Appearance
    'appearance_language': 'Language',
    'appearance_accent_color': 'Accent Color',
    'appearance_theme_light': 'Light',
    'appearance_theme_dark': 'Dark',
    'appearance_theme_system': 'System',

    // Buddy
    'buddy_name': 'Buddy Name',
    'buddy_name_hint': 'What should your buddy be called?',
    'buddy_name_saved': 'Buddy name saved ✅',
    'buddy_persona_edit': 'Edit Persona',
    'buddy_persona_desc': 'Character, rules, goals',
    'buddy_self_identity': 'My Self',
    'buddy_evolution': 'AI Evolution',
    'buddy_evolution_desc': 'Your agent learns more about you with every conversation.',
    'buddy_evolution_traits': 'traits learned',
    'buddy_evolution_empty': 'No traits learned yet',
    'buddy_memories': 'Memories',
    'buddy_offline_maps': 'Offline Maps',
    'buddy_offline_maps_desc': 'Tiles for offline navigation',
    'buddy_notes': 'Agent Notes',
    'buddy_notes_desc': 'What the AI can do — editable',
    'buddy_capabilities': 'My Capabilities',
    'buddy_capabilities_desc': 'What the AI can do — editable',

    // Tools
    'tools_section': 'Tools',
    'tools_desc': 'Tools, skills, passwords',

    // Config
    'config_provider': 'AI Model',
    'config_api_key': 'API Key',
    'config_model': 'Model',
    'config_model_hint': 'e.g. kimi-k2.6:cloud',
    'config_base_url': 'Base URL',
    'config_base_url_ollama': 'Base URL (e.g. https://ollama.com/api)',
    'config_base_url_openrouter': 'Base URL (default: https://openrouter.ai/api)',
    'config_base_url_openai': 'Base URL (default: https://api.openai.com)',
    'config_email': 'Email (IMAP)',
    'config_email_address': 'Email Address',
    'config_email_password': 'Password / App Password',
    'config_email_server': 'IMAP Server (e.g. imap.gmail.com)',
    'config_email_port': 'IMAP Port (default: 993)',
    'config_email_saved': 'Email configuration saved ✅',
    'config_embedding': 'Embedding (Memory Search)',
    'config_embedding_model': 'Model',
    'config_embedding_model_ollama': 'Model (e.g. nomic-embed-text)',
    'config_embedding_model_openai': 'Model (e.g. text-embedding-3-small)',
    'config_embedding_model_openrouter': 'Model (e.g. qwen/qwen3-embedding-8b)',
    'config_embedding_saved': 'Embedding configuration saved ✅',
    'config_embedding_ok': 'Embedding OK — Vector: {dim} dimensions',
    'config_embedding_error': 'Error: {msg}',
    'config_embedding_testing': 'Testing…',
    'config_embedding_no_result': 'Error: No embedding received',
    'config_tts': 'Speech Output',
    'config_tts_engine': 'TTS Engine',
    'config_tts_speed': 'Speech Speed',
    'config_tts_device_desc': 'Uses the device\'s system speech output. No download needed, but quality varies by device.',
    'config_tts_saved': 'Speech output saved ✅',
    'config_piper_voices': 'Piper Voices (offline)',
    'config_piper_language': 'Language: ',
    'config_piper_all_languages': 'All Languages',
    'config_piper_downloaded': 'Downloaded',
    'config_piper_not_downloaded': 'Not downloaded',
    'config_piper_downloading': 'Downloading… {pct}%',
    'config_piper_active': '✓ Active',
    'config_proactivity': 'Proactivity',
    'config_proactivity_off': 'Off',
    'config_proactivity_low': 'Low',
    'config_proactivity_normal': 'Normal',
    'config_proactivity_high': 'High',
    'config_proactivity_off_desc': 'No proactive messages',
    'config_proactivity_low_desc': 'Urgent reminders only',
    'config_proactivity_normal_desc': 'Time, place + routines',
    'config_proactivity_high_desc': 'Everything + learning',
    'config_saved': '{label} saved ✅',
    'config_testing': 'Testing…',
    'config_test_ok': '{label} OK — {text}',
    'config_test_fail': 'Error: {msg}',
    'config_test_message': 'You are a test. Reply briefly: OK',
    'config_test_hello': 'Hello, test!',
    'config_fallback': 'Fallback',
    'config_model_id': 'Model ID',
    'config_custom_id': 'Custom: {id}',
    'config_custom_id_hint': 'Enter custom ID…',

    // Data
    'data_backup': 'AI-Buddy Backup',
    'data_backup_create': 'Create Backup',
    'data_backup_created': 'Backup created — save it securely ✅',
    'data_backup_restore': 'Restore Backup',
    'data_backup_restore_confirm': 'Restore backup?',
    'data_backup_restored': 'Backup restored ✅',
    'data_backup_overwrite_warning': 'Current data will be overwritten.',
    'data_chat_delete': 'Delete Chat',
    'data_chat_delete_confirm': 'Delete chat history?',
    'data_chat_deleted': 'Chat history deleted',
    'data_memories_delete': 'Delete Memories',
    'data_memories_delete_confirm': 'Delete memories?',
    'data_memories_deleted': 'Memories deleted',
    'data_reset': 'Reset App',
    'data_reset_confirm': 'Completely reset app?',
    'data_reset_warning': 'Everything will be deleted: chat, memories, self-image, persona, AI evolution. This cannot be undone.',
    'data_reset_done': 'App reset — restart recommended',

    // Background Tasks
    'bg_tasks_title': 'Background Tasks',
    'bg_tasks_run_now': 'Run Now',

    // About
    'about_title': 'About',
    'about_version': 'Version {version}',

    // Chat Screen
    'chat_you': 'You',
    'chat_copied': 'Message(s) copied',
    'chat_attachment': 'Attachment',
    'chat_take_photo': 'Take Photo',
    'chat_from_gallery': 'From Gallery',
    'chat_osm_navigation': 'OSM Navigation',
    'chat_voice_ready': 'Ready',
    'chat_voice_listening': 'I\'m listening...',
    'chat_voice_thinking': 'Thinking...',
    'chat_voice_speaking': 'Speaking...',
    'chat_voice_error': 'Error',
    'chat_stop': 'Stop',

    // Time
    'time_just_now': 'just now',
    'time_minutes_ago': '{n} min ago',
    'time_hours_ago': '{n}h ago',
    'time_days_ago': '{n}d ago',

    // Speed
    'speed_slow': 'slow',
    'speed_fast': 'fast',

    // Memory
    'memory_core_long_short': 'Core, Long-term, Short-term',
    'memory_all_learn': 'All + Learn',

    // Proactivity
    'proactivity_time_place_routines': 'Time, place + routines',
    'proactivity_urgent_only': 'Urgent reminders only',
    'proactivity_none': 'No proactive messages',

    // Model names
    'model_claude_haiku': 'Claude 3.5 Haiku (fast)',
    'model_claude_sonnet': 'Claude 3.5 Sonnet (balanced)',
    'model_claude_opus': 'Claude Opus 4 (strongest)',
    'model_claude_sonnet4': 'Claude Sonnet 4 (balanced)',
    'model_gpt4o': 'GPT-4o (balanced)',
    'model_gpt4o_mini': 'GPT-4o mini (fast)',
    'model_gpt41': 'GPT-4.1 (creative)',
    'model_o4_mini': 'o4-mini (reasoning)',
    'model_gemini_flash': 'Gemini 2.0 Flash (fast)',
    'model_deepseek_v4': 'DeepSeek V4 Pro (128k)',
    'model_deepseek_flash': 'DeepSeek Flash V4 (fast)',
    'model_kimi_k2': 'Kimi K2.6 (262k context)',
    'bg_tasks_every_minutes': 'Every {n} min',
    'bg_tasks_last_run': 'Last run:',
    'data_reset_desc': 'Erase everything — like freshly installed',
    'config_openrouter_api_key': 'OpenRouter API Key',
  },

  // ═══════════════════════════════════════════
  // Deutsch
  // ═══════════════════════════════════════════
  'de': {
    // Welcome
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
    'welcome_embedding_model': 'Embedding-Modell',
    'welcome_embedding_model_hint': 'z.B. nomic-embed-text',
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

    // Common
    'common_cancel': 'Abbrechen',
    'common_save': 'Speichern',
    'common_done': 'Fertig',
    'common_error': 'Fehler',
    'common_delete': 'Löschen',
    'common_confirm': 'Bestätigen',
    'common_test': 'Testen',
    'common_download': 'Download',
    'common_load': 'Laden',
    'common_restore': 'Wiederherstellen',
    'common_ok': 'OK',
    'common_back': 'Zurück',
    'common_next': 'Weiter',
    'common_edit': 'Bearbeiten',
    'common_expand': 'Aufklappen zur Bearbeitung',
    'common_collapse': 'Einklappen zur Bearbeitung',
    'common_default': 'Standard',

    // Chat
    'chat_hint_message': 'Nachricht',
    'chat_error_timeout': 'Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.',
    'chat_error_generic': 'Es ist ein Fehler aufgetreten. Bitte versuche es erneut.',
    'chat_selected_count': '{count} ausgewählt',
    'chat_copied_count': '{count} Nachricht{count} kopiert',
    'chat_initial_prompt': 'Was kannst du alles für mich tun? Welche Tools und Features hast du?',

    // STT
    'stt_not_available': 'Spracherkennung nicht verfügbar',
    'stt_permission_needed': 'Mikrofon-Berechtigung benötigt',

    // Navigation
    'navigation_destination': 'Ziel',
    'navigation_steps': '{count} Schritte',
    'navigation_show_on_map': 'Auf Karte anzeigen',
    'map_label': 'Karte',
    'location_label': 'Standort',

    // Data bodies
    'data_chat_delete_body': 'Alle Nachrichten werden unwiderruflich gelöscht.',
    'data_memories_delete_body': 'Alle gespeicherten Erinnerungen werden gelöscht.',

    // Settings Tabs
    'settings_title': 'Einstellungen',
    'settings_tab_general': 'Allgemein',
    'settings_tab_appearance': 'Erscheinungsbild',
    'settings_tab_buddy': 'Buddy',
    'settings_tab_tools': 'Werkzeuge',
    'settings_tab_config': 'Konfiguration',
    'settings_tab_data': 'Daten',
    'settings_tab_background': 'Hintergrund-Tasks',
    'settings_tab_about': 'Über',

    // Appearance
    'appearance_language': 'Sprache / Language',
    'appearance_accent_color': 'Akzentfarbe',
    'appearance_theme_light': 'Hell',
    'appearance_theme_dark': 'Dunkel',
    'appearance_theme_system': 'System',

    // Buddy
    'buddy_name': 'Buddy-Name',
    'buddy_name_hint': 'Wie soll dein Buddy heißen?',
    'buddy_name_saved': 'Buddy-Name gespeichert ✅',
    'buddy_persona_edit': 'Persona bearbeiten',
    'buddy_persona_desc': 'Wesen, Regeln, Ziele',
    'buddy_self_identity': 'Mein Selbst',
    'buddy_evolution': 'KI-Entwicklung',
    'buddy_evolution_desc': 'Dein Agent lernt mit jedem Gespräch mehr über dich.',
    'buddy_evolution_traits': 'Merkmale gelernt',
    'buddy_evolution_empty': 'Noch keine Merkmale gelernt',
    'buddy_memories': 'Erinnerungen',
    'buddy_offline_maps': 'Offline-Karten',
    'buddy_offline_maps_desc': 'Kacheln fuer Navigation ohne Netz',
    'buddy_notes': 'Agent Notizen',
    'buddy_notes_desc': 'Was die KI alles kann — editierbar',
    'buddy_capabilities': 'Meine Fähigkeiten',
    'buddy_capabilities_desc': 'Was die KI alles kann — editierbar',

    // Tools
    'tools_section': 'Werkzeuge',
    'tools_desc': 'Werkzeuge, Skills, Passwörter',

    // Config
    'config_provider': 'KI-Modell',
    'config_api_key': 'API Key',
    'config_model': 'Modell',
    'config_model_hint': 'z.B. kimi-k2.6:cloud',
    'config_base_url': 'Base URL',
    'config_base_url_ollama': 'Base URL (z.B. https://ollama.com/api)',
    'config_base_url_openrouter': 'Base URL (Standard: https://openrouter.ai/api)',
    'config_base_url_openai': 'Base URL (Standard: https://api.openai.com)',
    'config_email': 'E-Mail (IMAP)',
    'config_email_address': 'E-Mail-Adresse',
    'config_email_password': 'Passwort / App-Passwort',
    'config_email_server': 'IMAP-Server (z.B. imap.gmail.com)',
    'config_email_port': 'IMAP-Port (Standard: 993)',
    'config_email_saved': 'E-Mail-Konfiguration gespeichert ✅',
    'config_embedding': 'Embedding (Memory-Suche)',
    'config_embedding_model': 'Modell',
    'config_embedding_model_ollama': 'Modell (z.B. nomic-embed-text)',
    'config_embedding_model_openai': 'Modell (z.B. text-embedding-3-small)',
    'config_embedding_model_openrouter': 'Modell (z.B. qwen/qwen3-embedding-8b)',
    'config_embedding_saved': 'Embedding-Konfiguration gespeichert ✅',
    'config_embedding_ok': 'Embedding OK — Vektor: {dim} Dimensionen',
    'config_embedding_error': 'Fehler: {msg}',
    'config_embedding_testing': 'Teste…',
    'config_embedding_no_result': 'Fehler: Kein Embedding erhalten',
    'config_tts': 'Sprachausgabe',
    'config_tts_engine': 'TTS Engine',
    'config_tts_speed': 'Sprechgeschwindigkeit',
    'config_tts_device_desc': 'Verwendet die System-Sprachausgabe des Geräts. Kein Download nötig, aber Qualität variiert je nach Gerät.',
    'config_tts_saved': 'Sprachausgabe gespeichert ✅',
    'config_piper_voices': 'Piper Stimmen (offline)',
    'config_piper_language': 'Sprache: ',
    'config_piper_all_languages': 'Alle Sprachen',
    'config_piper_downloaded': 'Heruntergeladen',
    'config_piper_not_downloaded': 'Nicht heruntergeladen',
    'config_piper_downloading': 'Wird heruntergeladen… {pct}%',
    'config_piper_active': '✓ Aktiv',
    'config_proactivity': 'Proaktivität',
    'config_proactivity_off': 'Aus',
    'config_proactivity_low': 'Niedrig',
    'config_proactivity_normal': 'Normal',
    'config_proactivity_high': 'Hoch',
    'config_proactivity_off_desc': 'Keine proaktiven Nachrichten',
    'config_proactivity_low_desc': 'Nur dringende Erinnerungen',
    'config_proactivity_normal_desc': 'Zeit, Ort + Routinen',
    'config_proactivity_high_desc': 'Alles + Lernen',
    'config_saved': '{label} gespeichert ✅',
    'config_testing': 'Teste…',
    'config_test_ok': '{label} OK — {text}',
    'config_test_fail': 'Fehler: {msg}',
    'config_test_message': 'Du bist ein Test. Antworte kurz: OK',
    'config_test_hello': 'Hallo, Test!',
    'config_fallback': 'Fallback',
    'config_model_id': 'Modell-ID',
    'config_custom_id': 'Eigene: {id}',
    'config_custom_id_hint': 'Eigene ID eingeben…',

    // Data
    'data_backup': 'AI-Buddy Backup',
    'data_backup_create': 'Backup erstellen',
    'data_backup_created': 'Backup erstellt — speicher es sicher ab ✅',
    'data_backup_restore': 'Backup wiederherstellen',
    'data_backup_restore_confirm': 'Backup wiederherstellen?',
    'data_backup_restored': 'Backup eingespielt ✅',
    'data_backup_overwrite_warning': 'Aktuelle Daten werden überschrieben.',
    'data_chat_delete': 'Chat löschen',
    'data_chat_delete_confirm': 'Chat-Verlauf löschen?',
    'data_chat_deleted': 'Chat-Verlauf gelöscht',
    'data_memories_delete': 'Erinnerungen löschen',
    'data_memories_delete_confirm': 'Erinnerungen löschen?',
    'data_memories_deleted': 'Erinnerungen gelöscht',
    'data_reset': 'App zurücksetzen',
    'data_reset_confirm': 'App komplett zurücksetzen?',
    'data_reset_warning': 'Alles wird gelöscht: Chat, Erinnerungen, Selbstbild, Persona, KI-Entwicklung. Das kann nicht rückgängig gemacht werden.',
    'data_reset_done': 'App zurückgesetzt — neu starten empfohlen',

    // Background Tasks
    'bg_tasks_title': 'Hintergrund-Tasks',
    'bg_tasks_run_now': 'Jetzt ausführen',

    // About
    'about_title': 'Über',
    'about_version': 'Version {version}',

    // Chat Screen
    'chat_you': 'Du',
    'chat_copied': 'Nachricht(en) kopiert',
    'chat_attachment': 'Anhang',
    'chat_take_photo': 'Foto aufnehmen',
    'chat_from_gallery': 'Aus Galerie',
    'chat_osm_navigation': 'OSM Navigation',
    'chat_voice_ready': 'Bereit',
    'chat_voice_listening': 'Ich höre zu...',
    'chat_voice_thinking': 'Denkt nach...',
    'chat_voice_speaking': 'Spricht...',
    'chat_voice_error': 'Fehler',
    'chat_stop': 'Stop',

    // Time
    'time_just_now': 'gerade eben',
    'time_minutes_ago': 'vor {n} Min',
    'time_hours_ago': 'vor {n}h',
    'time_days_ago': 'vor {n}d',

    // Speed
    'speed_slow': 'langsam',
    'speed_fast': 'schnell',

    // Memory
    'memory_core_long_short': 'Core, Langzeit, Kurzzeit',
    'memory_all_learn': 'Alles + Lernen',

    // Proactivity
    'proactivity_time_place_routines': 'Zeit, Ort + Routinen',
    'proactivity_urgent_only': 'Nur dringende Erinnerungen',
    'proactivity_none': 'Keine proaktiven Nachrichten',

    // Model names
    'model_claude_haiku': 'Claude 3.5 Haiku (schnell)',
    'model_claude_sonnet': 'Claude 3.5 Sonnet (ausgewogen)',
    'model_claude_opus': 'Claude Opus 4 (stärkster)',
    'model_claude_sonnet4': 'Claude Sonnet 4 (ausgewogen)',
    'model_gpt4o': 'GPT-4o (ausgewogen)',
    'model_gpt4o_mini': 'GPT-4o mini (schnell)',
    'model_gpt41': 'GPT-4.1 (kreativ)',
    'model_o4_mini': 'o4-mini (reasoning)',
    'model_gemini_flash': 'Gemini 2.0 Flash (schnell)',
    'model_deepseek_v4': 'DeepSeek V4 Pro (128k)',
    'model_deepseek_flash': 'DeepSeek Flash V4 (Schnell)',
    'model_kimi_k2': 'Kimi K2.6 (262k Kontext)',
    'bg_tasks_every_minutes': 'Alle {n} Min',
    'bg_tasks_last_run': 'Letztmals',
    'data_reset_desc': 'Alles löschen — wie neu installiert',
    'config_openrouter_api_key': 'OpenRouter API Key',
  },

  // ═══════════════════════════════════════════
  // Español
  // ═══════════════════════════════════════════
  'es': {
    // Welcome
    'welcome_title': 'Bienvenido a AI-Buddy',
    'welcome_subtitle': 'Tu compañero de IA — vamos a configurarlo.',
    'welcome_language_section': 'Elegir idioma',
    'welcome_language_hint': 'Puedes cambiarlo cuando quieras en Ajustes.',
    'welcome_config_section': 'Configuración rápida',
    'welcome_provider': 'Proveedor de IA',
    'welcome_api_key': 'Clave API',
    'welcome_api_key_hint': 'Tu clave API (guardada de forma segura en el dispositivo)',
    'welcome_model': 'Modelo',
    'welcome_model_hint': 'ej. kimi-k2:cloud, llama3.3:70b',
    'welcome_embedding_model': 'Modelo de Embedding',
    'welcome_embedding_model_hint': 'ej. nomic-embed-text',
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

    // Common
    'common_cancel': 'Cancelar',
    'common_save': 'Guardar',
    'common_done': 'Hecho',
    'common_error': 'Error',
    'common_delete': 'Eliminar',
    'common_confirm': 'Confirmar',
    'common_test': 'Probar',
    'common_download': 'Descargar',
    'common_load': 'Cargar',
    'common_restore': 'Restaurar',
    'common_ok': 'OK',
    'common_back': 'Atrás',
    'common_next': 'Siguiente',
    'common_edit': 'Editar',
    'common_expand': 'Expandir para editar',
    'common_collapse': 'Contraer para editar',
    'common_default': 'Predeterminado',

    // Chat
    'chat_hint_message': 'Mensaje',
    'chat_error_timeout': 'La solicitud tardó demasiado. Inténtalo de nuevo.',
    'chat_error_generic': 'Se produjo un error. Inténtalo de nuevo.',
    'chat_selected_count': '{count} seleccionado',
    'chat_copied_count': '{count} mensaje(s) copiado(s)',
    'chat_initial_prompt': '¿Qué puedes hacer por mí? ¿Qué herramientas y funciones tienes?',

    // STT
    'stt_not_available': 'Reconocimiento de voz no disponible',
    'stt_permission_needed': 'Se necesita permiso de micrófono',

    // Navigation
    'navigation_destination': 'Destino',
    'navigation_steps': '{count} pasos',
    'navigation_show_on_map': 'Mostrar en mapa',
    'map_label': 'Mapa',
    'location_label': 'Ubicación',

    // Data bodies
    'data_chat_delete_body': 'Todos los mensajes se eliminarán permanentemente.',
    'data_memories_delete_body': 'Todos los recuerdos guardados se eliminarán.',

    // Settings Tabs
    'settings_title': 'Ajustes',
    'settings_tab_general': 'General',
    'settings_tab_appearance': 'Apariencia',
    'settings_tab_buddy': 'Buddy',
    'settings_tab_tools': 'Herramientas',
    'settings_tab_config': 'Configuración',
    'settings_tab_data': 'Datos',
    'settings_tab_background': 'Tareas en segundo plano',
    'settings_tab_about': 'Acerca de',

    // Appearance
    'appearance_language': 'Idioma',
    'appearance_accent_color': 'Color de acento',
    'appearance_theme_light': 'Claro',
    'appearance_theme_dark': 'Oscuro',
    'appearance_theme_system': 'Sistema',

    // Buddy
    'buddy_name': 'Nombre del Buddy',
    'buddy_name_hint': '¿Cómo debería llamarse tu buddy?',
    'buddy_name_saved': 'Nombre del buddy guardado ✅',
    'buddy_persona_edit': 'Editar Persona',
    'buddy_persona_desc': 'Carácter, reglas, objetivos',
    'buddy_self_identity': 'Mi Identidad',
    'buddy_evolution': 'Evolución de IA',
    'buddy_evolution_desc': 'Tu agente aprende más sobre ti con cada conversación.',
    'buddy_evolution_traits': 'rasgos aprendidos',
    'buddy_evolution_empty': 'Aún no se han aprendido rasgos',
    'buddy_memories': 'Recuerdos',
    'buddy_offline_maps': 'Mapas sin conexión',
    'buddy_offline_maps_desc': 'Baldosas para navegación sin red',
    'buddy_notes': 'Notas del Agente',
    'buddy_notes_desc': 'Lo que la IA puede hacer — editable',
    'buddy_capabilities': 'Mis Capacidades',
    'buddy_capabilities_desc': 'Lo que la IA puede hacer — editable',

    // Tools
    'tools_section': 'Herramientas',
    'tools_desc': 'Herramientas, habilidades, contraseñas',

    // Config
    'config_provider': 'Modelo de IA',
    'config_api_key': 'Clave API',
    'config_model': 'Modelo',
    'config_model_hint': 'ej. kimi-k2.6:cloud',
    'config_base_url': 'URL Base',
    'config_base_url_ollama': 'URL Base (ej. https://ollama.com/api)',
    'config_base_url_openrouter': 'URL Base (predet.: https://openrouter.ai/api)',
    'config_base_url_openai': 'URL Base (predet.: https://api.openai.com)',
    'config_email': 'Correo (IMAP)',
    'config_email_address': 'Dirección de correo',
    'config_email_password': 'Contraseña / Contraseña de app',
    'config_email_server': 'Servidor IMAP (ej. imap.gmail.com)',
    'config_email_port': 'Puerto IMAP (predet.: 993)',
    'config_email_saved': 'Configuración de correo guardada ✅',
    'config_embedding': 'Embedding (Búsqueda de memoria)',
    'config_embedding_model': 'Modelo',
    'config_embedding_model_ollama': 'Modelo (ej. nomic-embed-text)',
    'config_embedding_model_openai': 'Modelo (ej. text-embedding-3-small)',
    'config_embedding_model_openrouter': 'Modelo (ej. qwen/qwen3-embedding-8b)',
    'config_embedding_saved': 'Configuración de embedding guardada ✅',
    'config_embedding_ok': 'Embedding OK — Vector: {dim} dimensiones',
    'config_embedding_error': 'Error: {msg}',
    'config_embedding_testing': 'Probando…',
    'config_embedding_no_result': 'Error: No se recibió embedding',
    'config_tts': 'Salida de voz',
    'config_tts_engine': 'Motor TTS',
    'config_tts_speed': 'Velocidad de voz',
    'config_tts_device_desc': 'Usa la salida de voz del sistema. No requiere descarga, pero la calidad varía según el dispositivo.',
    'config_tts_saved': 'Salida de voz guardada ✅',
    'config_piper_voices': 'Voces Piper (sin conexión)',
    'config_piper_language': 'Idioma: ',
    'config_piper_all_languages': 'Todos los idiomas',
    'config_piper_downloaded': 'Descargado',
    'config_piper_not_downloaded': 'No descargado',
    'config_piper_downloading': 'Descargando… {pct}%',
    'config_piper_active': '✓ Activo',
    'config_proactivity': 'Proactividad',
    'config_proactivity_off': 'Apagado',
    'config_proactivity_low': 'Bajo',
    'config_proactivity_normal': 'Normal',
    'config_proactivity_high': 'Alto',
    'config_proactivity_off_desc': 'Sin mensajes proactivos',
    'config_proactivity_low_desc': 'Solo recordatorios urgentes',
    'config_proactivity_normal_desc': 'Hora, lugar + rutinas',
    'config_proactivity_high_desc': 'Todo + aprendizaje',
    'config_saved': '{label} guardado ✅',
    'config_testing': 'Probando…',
    'config_test_ok': '{label} OK — {text}',
    'config_test_fail': 'Error: {msg}',
    'config_test_message': 'Eres una prueba. Responde brevemente: OK',
    'config_test_hello': '¡Hola, prueba!',
    'config_fallback': 'Respaldo',
    'config_model_id': 'ID del modelo',
    'config_custom_id': 'Personalizado: {id}',
    'config_custom_id_hint': 'Ingresar ID personalizado…',

    // Data
    'data_backup': 'Copia de seguridad de AI-Buddy',
    'data_backup_create': 'Crear copia de seguridad',
    'data_backup_created': 'Copia creada — guárdala de forma segura ✅',
    'data_backup_restore': 'Restaurar copia de seguridad',
    'data_backup_restore_confirm': '¿Restaurar copia de seguridad?',
    'data_backup_restored': 'Copia restaurada ✅',
    'data_backup_overwrite_warning': 'Los datos actuales serán sobrescritos.',
    'data_chat_delete': 'Eliminar chat',
    'data_chat_delete_confirm': '¿Eliminar historial de chat?',
    'data_chat_deleted': 'Historial de chat eliminado',
    'data_memories_delete': 'Eliminar recuerdos',
    'data_memories_delete_confirm': '¿Eliminar recuerdos?',
    'data_memories_deleted': 'Recuerdos eliminados',
    'data_reset': 'Restablecer app',
    'data_reset_confirm': '¿Restablecer completamente la app?',
    'data_reset_warning': 'Se eliminará todo: chat, recuerdos, identidad, persona, evolución de IA. Esto no se puede deshacer.',
    'data_reset_done': 'App restablecida — se recomienda reiniciar',

    // Background Tasks
    'bg_tasks_title': 'Tareas en segundo plano',
    'bg_tasks_run_now': 'Ejecutar ahora',

    // About
    'about_title': 'Acerca de',
    'about_version': 'Versión {version}',

    // Chat Screen
    'chat_you': 'Tú',
    'chat_copied': 'Mensaje(s) copiado(s)',
    'chat_attachment': 'Adjunto',
    'chat_take_photo': 'Tomar foto',
    'chat_from_gallery': 'De la galería',
    'chat_osm_navigation': 'Navegación OSM',
    'chat_voice_ready': 'Listo',
    'chat_voice_listening': 'Escuchando...',
    'chat_voice_thinking': 'Pensando...',
    'chat_voice_speaking': 'Hablando...',
    'chat_voice_error': 'Error',
    'chat_stop': 'Parar',

    // Time
    'time_just_now': 'ahora mismo',
    'time_minutes_ago': 'hace {n} min',
    'time_hours_ago': 'hace {n}h',
    'time_days_ago': 'hace {n}d',

    // Speed
    'speed_slow': 'lento',
    'speed_fast': 'rápido',

    // Memory
    'memory_core_long_short': 'Núcleo, Largo plazo, Corto plazo',
    'memory_all_learn': 'Todo + Aprender',

    // Proactivity
    'proactivity_time_place_routines': 'Hora, lugar + rutinas',
    'proactivity_urgent_only': 'Solo recordatorios urgentes',
    'proactivity_none': 'Sin mensajes proactivos',

    // Model names
    'model_claude_haiku': 'Claude 3.5 Haiku (rápido)',
    'model_claude_sonnet': 'Claude 3.5 Sonnet (equilibrado)',
    'model_claude_opus': 'Claude Opus 4 (más potente)',
    'model_claude_sonnet4': 'Claude Sonnet 4 (equilibrado)',
    'model_gpt4o': 'GPT-4o (equilibrado)',
    'model_gpt4o_mini': 'GPT-4o mini (rápido)',
    'model_gpt41': 'GPT-4.1 (creativo)',
    'model_o4_mini': 'o4-mini (razonamiento)',
    'model_gemini_flash': 'Gemini 2.0 Flash (rápido)',
    'model_deepseek_v4': 'DeepSeek V4 Pro (128k)',
    'model_deepseek_flash': 'DeepSeek Flash V4 (rápido)',
    'model_kimi_k2': 'Kimi K2.6 (contexto 262k)',
    'bg_tasks_every_minutes': 'Cada {n} min',
    'bg_tasks_last_run': 'Última vez:',
    'data_reset_desc': 'Borrar todo — como recién instalado',
    'config_openrouter_api_key': 'Clave API de OpenRouter',
  },

  // ═══════════════════════════════════════════
  // 日本語 (Japanese)
  // ═══════════════════════════════════════════
  'ja': {
    // Welcome
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
    'welcome_embedding_model': 'エンベディングモデル',
    'welcome_embedding_model_hint': '例: nomic-embed-text',
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

    // Common
    'common_cancel': 'キャンセル',
    'common_save': '保存',
    'common_done': '完了',
    'common_error': 'エラー',
    'common_delete': '削除',
    'common_confirm': '確認',
    'common_test': 'テスト',
    'common_download': 'ダウンロード',
    'common_load': '読み込み',
    'common_restore': '復元',
    'common_ok': 'OK',
    'common_back': '戻る',
    'common_next': '次へ',
    'common_edit': '編集',
    'common_expand': '展開して編集',
    'common_collapse': '折りたたんで編集',
    'common_default': 'デフォルト',

    // Chat
    'chat_hint_message': 'メッセージ',
    'chat_error_timeout': 'リクエストがタイムアウトしました。もう一度お試しください。',
    'chat_error_generic': 'エラーが発生しました。もう一度お試しください。',
    'chat_selected_count': '{count} 件選択',
    'chat_copied_count': '{count} 件のメッセージをコピーしました',
    'chat_initial_prompt': 'あなたは何ができますか？どんなツールと機能がありますか？',

    // STT
    'stt_not_available': '音声認識は利用できません',
    'stt_permission_needed': 'マイクの許可が必要です',

    // Navigation
    'navigation_destination': '目的地',
    'navigation_steps': '{count} ステップ',
    'navigation_show_on_map': '地図に表示',
    'map_label': '地図',
    'location_label': '場所',

    // Data bodies
    'data_chat_delete_body': 'すべてのメッセージが完全に削除されます。',
    'data_memories_delete_body': '保存された思い出がすべて削除されます。',

    // Settings Tabs
    'settings_title': '設定',
    'settings_tab_general': '一般',
    'settings_tab_appearance': '外観',
    'settings_tab_buddy': 'バディ',
    'settings_tab_tools': 'ツール',
    'settings_tab_config': '設定',
    'settings_tab_data': 'データ',
    'settings_tab_background': 'バックグラウンドタスク',
    'settings_tab_about': 'について',

    // Appearance
    'appearance_language': '言語',
    'appearance_accent_color': 'アクセントカラー',
    'appearance_theme_light': 'ライト',
    'appearance_theme_dark': 'ダーク',
    'appearance_theme_system': 'システム',

    // Buddy
    'buddy_name': 'バディ名',
    'buddy_name_hint': 'バディの名前は？',
    'buddy_name_saved': 'バディ名を保存しました ✅',
    'buddy_persona_edit': 'ペルソナを編集',
    'buddy_persona_desc': '性格、ルール、目標',
    'buddy_self_identity': '自分のこと',
    'buddy_evolution': 'AIの進化',
    'buddy_evolution_desc': 'エージェントは会話ごとにあなたのことを学びます。',
    'buddy_evolution_traits': '学習した特性',
    'buddy_evolution_empty': 'まだ特性は学習されていません',
    'buddy_memories': '思い出',
    'buddy_offline_maps': 'オフラインマップ',
    'buddy_offline_maps_desc': 'オフライン用タイル',
    'buddy_notes': 'エージェントノート',
    'buddy_notes_desc': 'AIができること — 編集可能',
    'buddy_capabilities': '自分の能力',
    'buddy_capabilities_desc': 'AIができること — 編集可能',

    // Tools
    'tools_section': 'ツール',
    'tools_desc': 'ツール、スキル、パスワード',

    // Config
    'config_provider': 'AIモデル',
    'config_api_key': 'APIキー',
    'config_model': 'モデル',
    'config_model_hint': '例: kimi-k2.6:cloud',
    'config_base_url': 'ベースURL',
    'config_base_url_ollama': 'ベースURL (例: https://ollama.com/api)',
    'config_base_url_openrouter': 'ベースURL (デフォルト: https://openrouter.ai/api)',
    'config_base_url_openai': 'ベースURL (デフォルト: https://api.openai.com)',
    'config_email': 'メール (IMAP)',
    'config_email_address': 'メールアドレス',
    'config_email_password': 'パスワード / アプリパスワード',
    'config_email_server': 'IMAPサーバー (例: imap.gmail.com)',
    'config_email_port': 'IMAPポート (デフォルト: 993)',
    'config_email_saved': 'メール設定を保存しました ✅',
    'config_embedding': '埋め込み (メモリ検索)',
    'config_embedding_model': 'モデル',
    'config_embedding_model_ollama': 'モデル (例: nomic-embed-text)',
    'config_embedding_model_openai': 'モデル (例: text-embedding-3-small)',
    'config_embedding_model_openrouter': 'モデル (例: qwen/qwen3-embedding-8b)',
    'config_embedding_saved': '埋め込み設定を保存しました ✅',
    'config_embedding_ok': '埋め込みOK — ベクトル: {dim}次元',
    'config_embedding_error': 'エラー: {msg}',
    'config_embedding_testing': 'テスト中…',
    'config_embedding_no_result': 'エラー: 埋め込みが受信されませんでした',
    'config_tts': '音声出力',
    'config_tts_engine': 'TTSエンジン',
    'config_tts_speed': '話速',
    'config_tts_device_desc': 'デバイスのシステム音声出力を使用します。ダウンロード不要ですが、品質はデバイスによって異なります。',
    'config_tts_saved': '音声出力を保存しました ✅',
    'config_piper_voices': 'Piper音声 (オフライン)',
    'config_piper_language': '言語: ',
    'config_piper_all_languages': 'すべての言語',
    'config_piper_downloaded': 'ダウンロード済み',
    'config_piper_not_downloaded': '未ダウンロード',
    'config_piper_downloading': 'ダウンロード中… {pct}%',
    'config_piper_active': '✓ アクティブ',
    'config_proactivity': '積極性',
    'config_proactivity_off': 'オフ',
    'config_proactivity_low': '低',
    'config_proactivity_normal': '標準',
    'config_proactivity_high': '高',
    'config_proactivity_off_desc': '積極的なメッセージなし',
    'config_proactivity_low_desc': '緊急のリマインダーのみ',
    'config_proactivity_normal_desc': '時間、場所 + ルーチン',
    'config_proactivity_high_desc': 'すべて + 学習',
    'config_saved': '{label} を保存しました ✅',
    'config_testing': 'テスト中…',
    'config_test_ok': '{label} OK — {text}',
    'config_test_fail': 'エラー: {msg}',
    'config_test_message': 'あなたはテストです。簡潔に返信してください: OK',
    'config_test_hello': 'こんにちは、テスト！',
    'config_fallback': 'フォールバック',
    'config_model_id': 'モデルID',
    'config_custom_id': 'カスタム: {id}',
    'config_custom_id_hint': 'カスタムIDを入力…',

    // Data
    'data_backup': 'AI-Buddy バックアップ',
    'data_backup_create': 'バックアップを作成',
    'data_backup_created': 'バックアップを作成しました — 安全に保存してください ✅',
    'data_backup_restore': 'バックアップを復元',
    'data_backup_restore_confirm': 'バックアップを復元しますか？',
    'data_backup_restored': 'バックアップを復元しました ✅',
    'data_backup_overwrite_warning': '現在のデータは上書きされます。',
    'data_chat_delete': 'チャットを削除',
    'data_chat_delete_confirm': 'チャット履歴を削除しますか？',
    'data_chat_deleted': 'チャット履歴を削除しました',
    'data_memories_delete': '思い出を削除',
    'data_memories_delete_confirm': '思い出を削除しますか？',
    'data_memories_deleted': '思い出を削除しました',
    'data_reset': 'アプリをリセット',
    'data_reset_confirm': 'アプリを完全にリセットしますか？',
    'data_reset_warning': 'すべて削除されます：チャット、思い出、自己イメージ、ペルソナ、AIの進化。元に戻せません。',
    'data_reset_done': 'アプリをリセットしました — 再起動をお勧めします',

    // Background Tasks
    'bg_tasks_title': 'バックグラウンドタスク',
    'bg_tasks_run_now': '今すぐ実行',

    // About
    'about_title': 'について',
    'about_version': 'バージョン {version}',

    // Chat Screen
    'chat_you': 'あなた',
    'chat_copied': 'メッセージをコピーしました',
    'chat_attachment': '添付',
    'chat_take_photo': '写真を撮る',
    'chat_from_gallery': 'ギャラリーから',
    'chat_osm_navigation': 'OSMナビゲーション',
    'chat_voice_ready': '準備完了',
    'chat_voice_listening': '聞いています...',
    'chat_voice_thinking': '考え中...',
    'chat_voice_speaking': '話しています...',
    'chat_voice_error': 'エラー',
    'chat_stop': '停止',

    // Time
    'time_just_now': 'たった今',
    'time_minutes_ago': '{n}分前',
    'time_hours_ago': '{n}時間前',
    'time_days_ago': '{n}日前',

    // Speed
    'speed_slow': '遅い',
    'speed_fast': '速い',

    // Memory
    'memory_core_long_short': 'コア、長期、短期',
    'memory_all_learn': 'すべて + 学習',

    // Proactivity
    'proactivity_time_place_routines': '時間、場所 + ルーチン',
    'proactivity_urgent_only': '緊急のリマインダーのみ',
    'proactivity_none': '積極的なメッセージなし',

    // Model names
    'model_claude_haiku': 'Claude 3.5 Haiku (高速)',
    'model_claude_sonnet': 'Claude 3.5 Sonnet (バランス)',
    'model_claude_opus': 'Claude Opus 4 (最強)',
    'model_claude_sonnet4': 'Claude Sonnet 4 (バランス)',
    'model_gpt4o': 'GPT-4o (バランス)',
    'model_gpt4o_mini': 'GPT-4o mini (高速)',
    'model_gpt41': 'GPT-4.1 (クリエイティブ)',
    'model_o4_mini': 'o4-mini (推論)',
    'model_gemini_flash': 'Gemini 2.0 Flash (高速)',
    'model_deepseek_v4': 'DeepSeek V4 Pro (128k)',
    'model_deepseek_flash': 'DeepSeek Flash V4 (高速)',
    'model_kimi_k2': 'Kimi K2.6 (262kコンテキスト)',
    'bg_tasks_every_minutes': '{n}分ごと',
    'bg_tasks_last_run': '最終実行:',
    'data_reset_desc': 'すべて消去 — 新規インストールと同じ',
    'config_openrouter_api_key': 'OpenRouter APIキー',
  },

  // ═══════════════════════════════════════════
  // 中文 (Mandarin Chinese)
  // ═══════════════════════════════════════════
  'zh': {
    // Welcome
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
    'welcome_embedding_model': '嵌入模型',
    'welcome_embedding_model_hint': '例如 nomic-embed-text',
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

    // Common
    'common_cancel': '取消',
    'common_save': '保存',
    'common_done': '完成',
    'common_error': '错误',
    'common_delete': '删除',
    'common_confirm': '确认',
    'common_test': '测试',
    'common_download': '下载',
    'common_load': '加载',
    'common_restore': '恢复',
    'common_ok': '确定',
    'common_back': '返回',
    'common_next': '下一步',
    'common_edit': '编辑',
    'common_expand': '展开编辑',
    'common_collapse': '折叠编辑',
    'common_default': '默认',

    // Chat
    'chat_hint_message': '消息',
    'chat_error_timeout': '请求超时，请重试。',
    'chat_error_generic': '发生错误，请重试。',
    'chat_selected_count': '已选择 {count} 项',
    'chat_copied_count': '已复制 {count} 条消息',
    'chat_initial_prompt': '你能为我做什么？你有什么工具和功能？',

    // STT
    'stt_not_available': '语音识别不可用',
    'stt_permission_needed': '需要麦克风权限',

    // Navigation
    'navigation_destination': '目的地',
    'navigation_steps': '{count} 步',
    'navigation_show_on_map': '在地图上显示',
    'map_label': '地图',
    'location_label': '位置',

    // Data bodies
    'data_chat_delete_body': '所有消息将被永久删除。',
    'data_memories_delete_body': '所有保存的记忆将被删除。',

    // Settings Tabs
    'settings_title': '设置',
    'settings_tab_general': '通用',
    'settings_tab_appearance': '外观',
    'settings_tab_buddy': '伙伴',
    'settings_tab_tools': '工具',
    'settings_tab_config': '配置',
    'settings_tab_data': '数据',
    'settings_tab_background': '后台任务',
    'settings_tab_about': '关于',

    // Appearance
    'appearance_language': '语言',
    'appearance_accent_color': '强调色',
    'appearance_theme_light': '浅色',
    'appearance_theme_dark': '深色',
    'appearance_theme_system': '跟随系统',

    // Buddy
    'buddy_name': '伙伴名称',
    'buddy_name_hint': '你的伙伴叫什么名字？',
    'buddy_name_saved': '伙伴名称已保存 ✅',
    'buddy_persona_edit': '编辑人格',
    'buddy_persona_desc': '性格、规则、目标',
    'buddy_self_identity': '自我认知',
    'buddy_evolution': 'AI进化',
    'buddy_evolution_desc': '你的代理在每次对话中都会更了解你。',
    'buddy_evolution_traits': '已学习的特征',
    'buddy_evolution_empty': '尚未学习任何特征',
    'buddy_memories': '记忆',
    'buddy_offline_maps': '离线地图',
    'buddy_offline_maps_desc': '离线导航瓦片',
    'buddy_notes': '代理笔记',
    'buddy_notes_desc': 'AI能做什么 — 可编辑',
    'buddy_capabilities': '我的能力',
    'buddy_capabilities_desc': 'AI能做什么 — 可编辑',

    // Tools
    'tools_section': '工具',
    'tools_desc': '工具、技能、密码',

    // Config
    'config_provider': 'AI模型',
    'config_api_key': 'API密钥',
    'config_model': '模型',
    'config_model_hint': '例如 kimi-k2.6:cloud',
    'config_base_url': '基础URL',
    'config_base_url_ollama': '基础URL (例如 https://ollama.com/api)',
    'config_base_url_openrouter': '基础URL (默认: https://openrouter.ai/api)',
    'config_base_url_openai': '基础URL (默认: https://api.openai.com)',
    'config_email': '邮箱 (IMAP)',
    'config_email_address': '邮箱地址',
    'config_email_password': '密码 / 应用密码',
    'config_email_server': 'IMAP服务器 (例如 imap.gmail.com)',
    'config_email_port': 'IMAP端口 (默认: 993)',
    'config_email_saved': '邮箱配置已保存 ✅',
    'config_embedding': '嵌入 (记忆搜索)',
    'config_embedding_model': '模型',
    'config_embedding_model_ollama': '模型 (例如 nomic-embed-text)',
    'config_embedding_model_openai': '模型 (例如 text-embedding-3-small)',
    'config_embedding_model_openrouter': '模型 (例如 qwen/qwen3-embedding-8b)',
    'config_embedding_saved': '嵌入配置已保存 ✅',
    'config_embedding_ok': '嵌入正常 — 向量: {dim} 维',
    'config_embedding_error': '错误: {msg}',
    'config_embedding_testing': '测试中…',
    'config_embedding_no_result': '错误: 未收到嵌入',
    'config_tts': '语音输出',
    'config_tts_engine': 'TTS引擎',
    'config_tts_speed': '语速',
    'config_tts_device_desc': '使用设备的系统语音输出。无需下载，但质量因设备而异。',
    'config_tts_saved': '语音输出已保存 ✅',
    'config_piper_voices': 'Piper语音 (离线)',
    'config_piper_language': '语言: ',
    'config_piper_all_languages': '所有语言',
    'config_piper_downloaded': '已下载',
    'config_piper_not_downloaded': '未下载',
    'config_piper_downloading': '下载中… {pct}%',
    'config_piper_active': '✓ 活跃',
    'config_proactivity': '主动性',
    'config_proactivity_off': '关闭',
    'config_proactivity_low': '低',
    'config_proactivity_normal': '标准',
    'config_proactivity_high': '高',
    'config_proactivity_off_desc': '无主动消息',
    'config_proactivity_low_desc': '仅紧急提醒',
    'config_proactivity_normal_desc': '时间、地点 + 日常',
    'config_proactivity_high_desc': '全部 + 学习',
    'config_saved': '{label} 已保存 ✅',
    'config_testing': '测试中…',
    'config_test_ok': '{label} 正常 — {text}',
    'config_test_fail': '错误: {msg}',
    'config_test_message': '你是一个测试。请简短回复: OK',
    'config_test_hello': '你好，测试！',
    'config_fallback': '备用',
    'config_model_id': '模型ID',
    'config_custom_id': '自定义: {id}',
    'config_custom_id_hint': '输入自定义ID…',

    // Data
    'data_backup': 'AI-Buddy 备份',
    'data_backup_create': '创建备份',
    'data_backup_created': '备份已创建 — 请安全保存 ✅',
    'data_backup_restore': '恢复备份',
    'data_backup_restore_confirm': '恢复备份？',
    'data_backup_restored': '备份已恢复 ✅',
    'data_backup_overwrite_warning': '当前数据将被覆盖。',
    'data_chat_delete': '删除聊天',
    'data_chat_delete_confirm': '删除聊天记录？',
    'data_chat_deleted': '聊天记录已删除',
    'data_memories_delete': '删除记忆',
    'data_memories_delete_confirm': '删除记忆？',
    'data_memories_deleted': '记忆已删除',
    'data_reset': '重置应用',
    'data_reset_confirm': '完全重置应用？',
    'data_reset_warning': '将删除所有内容：聊天、记忆、自我形象、人格、AI进化。此操作不可撤销。',
    'data_reset_done': '应用已重置 — 建议重新启动',

    // Background Tasks
    'bg_tasks_title': '后台任务',
    'bg_tasks_run_now': '立即执行',

    // About
    'about_title': '关于',
    'about_version': '版本 {version}',

    // Chat Screen
    'chat_you': '你',
    'chat_copied': '消息已复制',
    'chat_attachment': '附件',
    'chat_take_photo': '拍照',
    'chat_from_gallery': '从相册',
    'chat_osm_navigation': 'OSM导航',
    'chat_voice_ready': '就绪',
    'chat_voice_listening': '正在听...',
    'chat_voice_thinking': '思考中...',
    'chat_voice_speaking': '说话中...',
    'chat_voice_error': '错误',
    'chat_stop': '停止',

    // Time
    'time_just_now': '刚刚',
    'time_minutes_ago': '{n}分钟前',
    'time_hours_ago': '{n}小时前',
    'time_days_ago': '{n}天前',

    // Speed
    'speed_slow': '慢',
    'speed_fast': '快',

    // Memory
    'memory_core_long_short': '核心、长期、短期',
    'memory_all_learn': '全部 + 学习',

    // Proactivity
    'proactivity_time_place_routines': '时间、地点 + 日常',
    'proactivity_urgent_only': '仅紧急提醒',
    'proactivity_none': '无主动消息',

    // Model names
    'model_claude_haiku': 'Claude 3.5 Haiku (快速)',
    'model_claude_sonnet': 'Claude 3.5 Sonnet (均衡)',
    'model_claude_opus': 'Claude Opus 4 (最强)',
    'model_claude_sonnet4': 'Claude Sonnet 4 (均衡)',
    'model_gpt4o': 'GPT-4o (均衡)',
    'model_gpt4o_mini': 'GPT-4o mini (快速)',
    'model_gpt41': 'GPT-4.1 (创意)',
    'model_o4_mini': 'o4-mini (推理)',
    'model_gemini_flash': 'Gemini 2.0 Flash (快速)',
    'model_deepseek_v4': 'DeepSeek V4 Pro (128k)',
    'model_deepseek_flash': 'DeepSeek Flash V4 (快速)',
    'model_kimi_k2': 'Kimi K2.6 (262k上下文)',
    'bg_tasks_every_minutes': '每{n}分钟',
    'bg_tasks_last_run': '上次运行:',
    'data_reset_desc': '清除全部 — 如同全新安装',
    'config_openrouter_api_key': 'OpenRouter API密钥',
  },
};
