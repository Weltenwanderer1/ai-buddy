import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';
import '../services/buddy_capabilities_service.dart';

class BuddyCapabilitiesScreen extends StatefulWidget {
  const BuddyCapabilitiesScreen({super.key});

  @override
  State<BuddyCapabilitiesScreen> createState() => _BuddyCapabilitiesScreenState();
}

class _BuddyCapabilitiesScreenState extends State<BuddyCapabilitiesScreen> {
  final _ctl = TextEditingController();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final caps = context.read<BuddyCapabilitiesService>().capabilities;
    _ctl.text = caps;
    _ctl.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<BuddyCapabilitiesService>().updateCapabilities(_ctl.text);
    if (!mounted) return;
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Fähigkeiten gespeichert ✓', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.buddy.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(children: [
                const SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.buddy.card.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.buddy.border.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: context.buddy.t1, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Meine Fähigkeiten',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.buddy.t1))),
                    if (_dirty)
                      GestureDetector(
                        onTap: _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Speichern',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('Hier weiß die KI, was sie kann — editierbar',
                  style: TextStyle(fontSize: 13, color: context.buddy.t2)),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.buddy.card.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.buddy.border.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _ctl,
                  maxLines: null,
                  minLines: 25,
                  style: TextStyle(color: context.buddy.t1, fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Fähigkeiten beschreiben...',
                    hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
