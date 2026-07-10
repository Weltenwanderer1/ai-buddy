import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/persona_service.dart';
import '../services/secure_config_service.dart';
import '../services/settings_service.dart';

/// Multi-step onboarding shown on first launch.
/// Steps: Language → Provider/API → Buddy Name + Appearance → Done
class WelcomeScreen extends StatefulWidget {
  final SettingsService settings;
  final SecureConfigService secureConfig;
  final PersonaService persona;
  final VoidCallback onComplete;

  const WelcomeScreen({
    super.key,
    required this.settings,
    required this.secureConfig,
    required this.persona,
    required this.onComplete,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _step = 0;
  final _totalSteps = 4;

  // Language
  String _selectedLang = 'en';

  // Provider
  String _provider = 'ollama'; // ollama | openrouter | openai | anthropic | skip
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _embeddingModelController = TextEditingController();
  bool _testing = false;
  String? _testResult;

  // Buddy name
  final _buddyNameController = TextEditingController();

  // Appearance
  String _themeMode = 'system';
  Color _accentColor = const Color(0xFF6B8DD6);

  @override
  void initState() {
    super.initState();
    // Load existing model from config, or use provider default
    final existingModel = widget.secureConfig.activeModel;
    _modelController.text = existingModel.isNotEmpty ? existingModel : 'kimi-k2.6:cloud';
    _embeddingModelController.text = widget.secureConfig.embeddingModel;
    _buddyNameController.text = widget.secureConfig.buddyName;
    if (_buddyNameController.text == 'Buddy') {
      _buddyNameController.clear();
    }
    // Load existing provider selection
    _provider = widget.secureConfig.llmProvider;
    _themeMode = widget.settings['theme_mode'] as String? ?? 'system';
    _accentColor = widget.settings.accentColor;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _embeddingModelController.dispose();
    _buddyNameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    // Capture localization before any async gaps
    final t = AppLocalizations.of(context);

    // Save language
    widget.settings.appLanguage = _selectedLang;

    // Save provider config
    if (_provider != 'skip') {
      await widget.secureConfig.setLlmProvider(_provider);
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        switch (_provider) {
          case 'ollama':
            await widget.secureConfig.setOllamaApiKey(apiKey);
          case 'openrouter':
            await widget.secureConfig.setOpenRouterApiKey(apiKey);
          case 'openai':
            await widget.secureConfig.setOpenAIApiKey(apiKey);
          case 'anthropic':
            await widget.secureConfig.setAnthropicApiKey(apiKey);
        }
      }
      final model = _modelController.text.trim();
      if (model.isNotEmpty) {
        switch (_provider) {
          case 'ollama':
            await widget.secureConfig.setOllamaModel(model);
          case 'openrouter':
            await widget.secureConfig.setOpenRouterModel(model);
          case 'openai':
            await widget.secureConfig.setOpenAIModel(model);
          case 'anthropic':
            await widget.secureConfig.setAnthropicModel(model);
        }
      }
      // Embedding model (shared across providers — uses same provider's API)
      final embeddingModel = _embeddingModelController.text.trim();
      if (embeddingModel.isNotEmpty) {
        await widget.secureConfig.setEmbeddingModel(embeddingModel);
      }
    }

    // Buddy name → secureConfig + persona
    final buddyName = _buddyNameController.text.trim();
    if (buddyName.isNotEmpty) {
      await widget.secureConfig.setBuddyName(buddyName);
      // Save to persona with localized defaults (t captured at top of method)
      final traits = t.welcome_default_personality
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.persona.save(
        name: buddyName,
        personality: traits,
        greeting: t.welcome_default_greeting,
      );
    }

    // Theme
    widget.settings['theme_mode'] = _themeMode;
    widget.settings.accentColor = _accentColor;

    // Mark onboarding complete
    widget.settings.onboardingComplete = true;

    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    HttpClient? client;
    try {
      final baseUrl = switch (_provider) {
        'openrouter' => 'https://openrouter.ai/api',
        'openai' => 'https://api.openai.com',
        'anthropic' => 'https://api.anthropic.com',
        // Ohne /api — Ollama Cloud serviert die OpenAI-kompatible Model-Liste
        // unter /v1/models (mit /api würde /api/v1/models 404 liefern).
        _ => 'https://ollama.com',
      };
      final apiKey = _apiKeyController.text.trim();
      // Simple connectivity test: fetch models endpoint
      final url = Uri.parse('$baseUrl/v1/models');
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(url);
      if (apiKey.isNotEmpty) {
        if (_provider == 'anthropic') {
          req.headers.set('x-api-key', apiKey);
          req.headers.set('anthropic-version', '2023-06-01');
        } else {
          req.headers.set('Authorization', 'Bearer $apiKey');
        }
      }
      final res = await req.close().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = res.statusCode == 200 ? 'success' : 'fail';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'fail';
      });
    } finally {
      // force: true releases the socket even though we never drained the
      // response body (we only need the status code) — otherwise the
      // connection lingers until timeout on every test tap.
      client?.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Localize THIS screen's own context — locale follows the live selection
      locale: Locale(_selectedLang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: AppTheme.dark(AppColors.primary),
      darkTheme: AppTheme.dark(AppColors.primary),
      themeMode: ThemeMode.dark,
      // Builder resolves `t` from the INNER context so tapping a language
      // updates the wizard text immediately (the outer app's locale is stale).
      home: Builder(builder: (innerContext) {
        final t = AppLocalizations.of(innerContext);
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.bgGradient),
            child: SafeArea(
              child: Column(
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildStep(t, _step),
                    ),
                  ),
                  // Nav buttons
                  _buildNav(t),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStep(AppLocalizations t, int step) {
    return switch (step) {
      0 => _buildLanguageStep(t),
      1 => _buildProviderStep(t),
      2 => _buildAppearanceStep(t),
      3 => _buildDoneStep(t),
      _ => _buildLanguageStep(t),
    };
  }

  // ── Step 0: Language ──
  Widget _buildLanguageStep(AppLocalizations t) {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.language,
            title: t.welcome_language_section,
            subtitle: t.welcome_language_hint,
          ),
          const SizedBox(height: 36),
          ...AppLocalizations.supportedLocales.map((loc) {
            final info = AppLocalizations.languageInfo[loc.languageCode]!;
            final selected = _selectedLang == loc.languageCode;
            return _LangTile(
              info: info,
              selected: selected,
              onTap: () => setState(() {
                _selectedLang = loc.languageCode;
                _refreshLocale();
              }),
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  void _refreshLocale() {
    // Force rebuild with new locale
    setState(() {});
  }

  // ── Step 1: Provider / API ──
  Widget _buildProviderStep(AppLocalizations t) {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.cloud_outlined,
            title: t.welcome_config_section,
            subtitle: t.welcome_optional,
          ),
          const SizedBox(height: 24),
          // Provider selector
          _ProviderTile(
            label: t.welcome_provider_ollama,
            icon: Icons.cloud,
            selected: _provider == 'ollama',
            onTap: () => setState(() {
              _provider = 'ollama';
              _modelController.text = 'kimi-k2.6:cloud';
            }),
          ),
          _ProviderTile(
            label: t.welcome_provider_openrouter,
            icon: Icons.hub,
            selected: _provider == 'openrouter',
            onTap: () => setState(() {
              _provider = 'openrouter';
              _modelController.text = 'anthropic/claude-3.5-sonnet';
            }),
          ),
          _ProviderTile(
            label: t.welcome_provider_openai,
            icon: Icons.psychology,
            selected: _provider == 'openai',
            onTap: () => setState(() {
              _provider = 'openai';
              _modelController.text = 'gpt-4o';
            }),
          ),
          _ProviderTile(
            label: t.welcome_provider_anthropic,
            icon: Icons.auto_awesome,
            selected: _provider == 'anthropic',
            onTap: () => setState(() {
              _provider = 'anthropic';
              _modelController.text = 'claude-sonnet-4-20250514';
            }),
          ),
          _ProviderTile(
            label: t.welcome_provider_skip,
            icon: Icons.skip_next,
            selected: _provider == 'skip',
            onTap: () => setState(() => _provider = 'skip'),
          ),
          if (_provider != 'skip') ...[
            const SizedBox(height: 28),
            _TextField(
              controller: _apiKeyController,
              label: t.welcome_api_key,
              hint: t.welcome_api_key_hint,
              obscure: true,
              icon: Icons.key,
            ),
            const SizedBox(height: 16),
            _TextField(
              controller: _modelController,
              label: t.welcome_model,
              hint: t.welcome_model_hint,
              icon: Icons.model_training,
            ),
            const SizedBox(height: 16),
            _TextField(
              controller: _embeddingModelController,
              label: t.welcome_embedding_model,
              hint: t.welcome_embedding_model_hint,
              icon: Icons.memory,
            ),
            const SizedBox(height: 16),
            // Test button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(Icons.wifi_tethering, color: AppColors.primary),
                label: Text(
                  _testing
                      ? t.welcome_testing
                      : t.welcome_test_connection,
                  style: TextStyle(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _testResult == 'success' ? Icons.check_circle : Icons.error,
                    color: _testResult == 'success' ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _testResult == 'success' ? t.welcome_test_success : t.welcome_test_fail,
                    style: TextStyle(
                      color: _testResult == 'success' ? AppColors.success : AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ],
          const Spacer(),
        ],
      ),
    );
  }

  // ── Step 2: Buddy Name + Appearance ──
  Widget _buildAppearanceStep(AppLocalizations t) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.face,
            title: t.welcome_buddy_name,
            subtitle: t.welcome_optional,
          ),
          const SizedBox(height: 16),
          _TextField(
            controller: _buddyNameController,
            label: t.welcome_buddy_name,
            hint: t.welcome_buddy_name_hint,
            icon: Icons.smart_toy_outlined,
          ),
          const SizedBox(height: 32),
          _StepHeader(
            icon: Icons.palette_outlined,
            title: t.welcome_theme,
            subtitle: '',
          ),
          const SizedBox(height: 12),
          // Theme mode selector
          Row(
            children: [
              Expanded(child: _ThemeChip(
                label: t.welcome_theme_light,
                icon: Icons.light_mode_outlined,
                selected: _themeMode == 'light',
                onTap: () => setState(() => _themeMode = 'light'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ThemeChip(
                label: t.welcome_theme_dark,
                icon: Icons.dark_mode_outlined,
                selected: _themeMode == 'dark',
                onTap: () => setState(() => _themeMode = 'dark'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ThemeChip(
                label: t.welcome_theme_system,
                icon: Icons.settings_brightness,
                selected: _themeMode == 'system',
                onTap: () => setState(() => _themeMode = 'system'),
              )),
            ],
          ),
          const SizedBox(height: 28),
          // Accent color
          Text(
            t.welcome_accent,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _accentColors.map((c) {
              final selected = _accentColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _accentColor = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Step 3: Done ──
  Widget _buildDoneStep(AppLocalizations t) {
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            t.welcome_done_title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            t.welcome_done_body,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: FilledButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: Text(
                  t.welcome_done_action,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation bar ──
  Widget _buildNav(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(t.welcome_back),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          if (_step < _totalSteps - 1)
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                label: Text(
                  t.welcome_next,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Widgets ──

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _LangTile extends StatelessWidget {
  final LangInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _LangTile({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(info.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      info.englishLabel,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 24)
              else
                Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primary, size: 22)
              else
                Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final IconData icon;
  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: !obscure,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accent color presets (same as settings) ──
const _accentColors = <Color>[
  Color(0xFF6B8DD6), // Periwinkle
  Color(0xFF5B9BD5), // Blue
  Color(0xFF34C759), // Green
  Color(0xFFFF9500), // Orange
  Color(0xFFFF3B30), // Red
  Color(0xFFFF6B9D), // Pink
  Color(0xFFA855F7), // Purple
  Color(0xFF64D2FF), // Cyan
  Color(0xFFD4AF37), // Gold
  Color(0xFF9BA0A3), // Gray
];