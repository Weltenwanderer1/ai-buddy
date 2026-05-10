import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import 'memory_browser_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import '../services/persona_service.dart';
import '../core/theme/app_colors.dart';

/// Scaffold mit Bottom Navigation: Chat | Erinnerungen | Einstellungen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  final _screens = const [
    ChatScreen(),
    MemoryBrowserScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final persona = context.watch<PersonaService>();

    if (!persona.isComplete && _idx == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OnboardingRedirect(onboardingPersona: persona),
          ));
        }
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _idx,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDark.withOpacity(0.85),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  active: _idx == 0,
                  onTap: () => setState(() => _idx = 0),
                ),
                _NavItem(
                  icon: Icons.memory,
                  label: 'Erinnerungen',
                  active: _idx == 1,
                  onTap: () => setState(() => _idx = 1),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Einstellungen',
                  active: _idx == 2,
                  onTap: () => setState(() => _idx = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppColors.animNormal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: active
            ? BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textTertiary, size: active ? 22 : 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textTertiary,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Platzhalter falls Onboarding nötig.
class OnboardingRedirect extends StatelessWidget {
  final PersonaService onboardingPersona;
  const OnboardingRedirect({super.key, required this.onboardingPersona});

  @override
  Widget build(BuildContext context) => OnboardingScreen(persona: onboardingPersona);
}