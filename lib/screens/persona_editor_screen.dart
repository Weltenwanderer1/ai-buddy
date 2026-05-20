import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/persona_service.dart';

class PersonaEditorScreen extends StatefulWidget {
  const PersonaEditorScreen({super.key});

  @override
  State<PersonaEditorScreen> createState() => _PersonaEditorScreenState();
}

class _PersonaEditorScreenState extends State<PersonaEditorScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _personalityController = TextEditingController();
  final _greetingController = TextEditingController();
  final _backstoryController = TextEditingController();
  String? _previewPrompt;
  late AnimationController _saveAnim;
  bool _isSaving = false;

  // Preset personality traits chips
  final List<String> _presetTraits = [
    'freundlich', 'humorvoll', 'direkt', 'ruhig', 'energisch',
    'geduldig', 'kreativ', 'analytisch', 'fürsorglich', 'sarkastisch',
    'motivierend', 'neugierig', 'optimistisch', 'pragmatisch',
  ];

  @override
  void initState() {
    super.initState();
    final persona = context.read<PersonaService>();
    _nameController.text = persona.name;
    _personalityController.text = persona.personality.join(', ');
    _greetingController.text = persona.greeting;
    _backstoryController.text = persona.backstory;
    _updatePreview();
    _saveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _saveAnim.dispose();
    _nameController.dispose();
    _personalityController.dispose();
    _greetingController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final traits = _personalityController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final buffer = StringBuffer('Du bist ${_nameController.text}.');
    if (traits.isNotEmpty) buffer.write(' Deine Persönlichkeit: ${traits.join(', ')}.');
    if (_backstoryController.text.isNotEmpty) buffer.write(' Hintergrund: ${_backstoryController.text}.');
    buffer.write(' Sei natürlich, hilfsbereit und charakterstark in deinen Antworten.');
    setState(() => _previewPrompt = buffer.toString());
  }

  void _addTrait(String trait) {
    final current = _personalityController.text;
    if (current.isEmpty) {
      _personalityController.text = trait;
    } else {
      final traits = current.split(',').map((s) => s.trim()).toList();
      if (!traits.contains(trait)) {
        _personalityController.text = '$current, $trait';
      }
    }
    _updatePreview();
    setState(() {});
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Name darf nicht leer sein', AppColors.error);
      return;
    }

    setState(() => _isSaving = true);
    _saveAnim.forward();

    final personality = _personalityController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final persona = context.read<PersonaService>();
    await persona.save(
      name: _nameController.text.trim(),
      personality: personality,
      greeting: _greetingController.text.trim(),
      backstory: _backstoryController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      _showSnack('Persona gespeichert', AppColors.success);
      final navigator = Navigator.of(context);
      Future.delayed(const Duration(milliseconds: 800), () => navigator.pop());
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  String get _avatarInitials =>
      _nameController.text.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Back button + title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.glassBg.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.glassBorder.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Persona bearbeiten',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isSaving ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _isSaving
                                  ? LinearGradient(colors: [
                                      AppColors.success.withValues(alpha: 0.6),
                                      AppColors.primary.withValues(alpha: 0.6),
                                    ])
                                  : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSaving) ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                Text(
                                  _isSaving ? 'Speichere...' : 'Speichern',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Avatar circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _avatarInitials.isEmpty ? '?' : _avatarInitials,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text.trim().isEmpty ? 'Dein Buddy' : _nameController.text.trim(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_greetingController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${_greetingController.text}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Form content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Name', Icons.badge_outlined),
                  _buildGlassTextField(
                    controller: _nameController,
                    hint: 'Name deines Buddies',
                    icon: Icons.face_rounded,
                    onChanged: (_) => _updatePreview(),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('Persönlichkeit', Icons.psychology_outlined),
                  _buildGlassTextField(
                    controller: _personalityController,
                    hint: 'freundlich, humorvoll, direkt...',
                    icon: Icons.format_quote_rounded,
                    onChanged: (_) => _updatePreview(),
                  ),
                  const SizedBox(height: 12),
                  // Trait chips
                  Text(
                    'Vorschläge:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetTraits.map((trait) {
                      final isSelected = _personalityController.text
                          .split(',')
                          .map((s) => s.trim())
                          .contains(trait);
                      return GestureDetector(
                        onTap: () => _addTrait(trait),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : AppColors.bgCard.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : AppColors.glassBorder.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            trait,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('Begrüßung', Icons.waving_hand_rounded),
                  _buildGlassTextField(
                    controller: _greetingController,
                    hint: 'Hey, was geht?',
                    icon: Icons.chat_bubble_outline_rounded,
                    onChanged: (_) => _updatePreview(),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('Backstory', Icons.auto_stories_rounded),
                  _buildGlassTextField(
                    controller: _backstoryController,
                    hint: 'Erzähle von der Herkunft deines Buddies...',
                    icon: Icons.history_edu_rounded,
                    maxLines: 4,
                    onChanged: (_) => _updatePreview(),
                  ),

                  const SizedBox(height: 32),

                  // Preview card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.glassBorder.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.preview_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'System-Prompt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.glassBorder.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            _previewPrompt ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving) ...[
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else
                            const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                          Text(
                            _isSaving ? 'Speichere...' : 'Persona speichern',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textTertiary.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
