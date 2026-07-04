import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';
import '../services/persona_service.dart';

class OnboardingScreen extends StatefulWidget {
  final PersonaService persona;
  const OnboardingScreen({super.key, required this.persona});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtl = TextEditingController();
  final _personalityCtl = TextEditingController(
      text: 'freundlich, neugierig, hilfsbereit');
  final _greetingCtl = TextEditingController(
      text: 'Hallo! Wie kann ich dir helfen?');

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showCheck = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtl.dispose();
    _personalityCtl.dispose();
    _greetingCtl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (page == 2) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showCheck = true);
      });
    }
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.buddy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.buddy.border),
      ),
      child: child,
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required Widget child,
    LinearGradient? gradient,
  }) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.buddy.bg,
      body: Container(
        color: context.buddy.bg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      GestureDetector(
                        onTap: _prevPage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.buddy.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.buddy.border),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: context.buddy.t1,
                            size: 20,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (_currentPage == 0)
                      GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeInOutCubic,
                        ),
                        child: Text(
                          'Überspringen',
                          style: TextStyle(
                            color: context.buddy.t2,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── PageView ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildWelcomePage(),
                    _buildSetupPage(),
                    _buildFinishPage(),
                  ],
                ),
              ),

              // ── Page indicator ──
              Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: AppColors.animNormal,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primary
                            : context.buddy.t3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seite 1: Willkommen ──
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gradient Circle + Icon
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 56),
          Text(
            'Willkommen bei AI-Buddy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: context.buddy.t1,
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Dein persönlicher KI-Companion',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.buddy.t2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 72),
          _buildGradientButton(
            onPressed: _nextPage,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Loslegen',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Seite 2: Persona einrichten ──
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar-Preview
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.secondaryGradient,
              border: Border.all(color: context.buddy.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameCtl,
                builder: (context, value, _) {
                  final initials = value.text.isEmpty
                      ? '?'
                      : value.text.substring(0, 1).toUpperCase();
                  return Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Persona einrichten',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.buddy.t1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gib deinem Buddy einen Namen und Charakter',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.buddy.t2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Name
          _buildTextField(
            controller: _nameCtl,
            label: 'Name',
            hint: 'z.\u00A0B. Buddy',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // Persönlichkeit
          _buildTextField(
            controller: _personalityCtl,
            label: 'Persönlichkeit',
            hint: 'freundlich, neugierig, hilfsbereit',
            icon: Icons.psychology_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Begrüßung
          _buildTextField(
            controller: _greetingCtl,
            label: 'Begrüßung',
            hint: 'Hallo! Wie kann ich dir helfen?',
            icon: Icons.waving_hand_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 36),

          _buildGradientButton(
            onPressed: _nextPage,
            child: const Text(
              'Weiter',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return _buildGlassCard(
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: context.buddy.t1),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: context.buddy.t2),
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: context.buddy.t2,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: context.buddy.t3,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  // ── Seite 3: Fertig ──
  Widget _buildFinishPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Checkmark
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _showCheck ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, value, _) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 56),
          Text(
            'Alles bereit — lass uns chatten!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.buddy.t1,
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Dein AI-Buddy ist ganz auf dich eingestellt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.buddy.t2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 72),
          _buildGradientButton(
            onPressed: _save,
            child: const Text(
              'Chat starten',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim().isEmpty ? 'Buddy' : _nameCtl.text.trim();
    final traits = _personalityCtl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await widget.persona.save(
      name: name,
      personality: traits,
      greeting: _greetingCtl.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
