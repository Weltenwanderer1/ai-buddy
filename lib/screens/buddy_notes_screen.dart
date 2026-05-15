import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/buddy_notes_service.dart';

class BuddyNotesScreen extends StatefulWidget {
  const BuddyNotesScreen({super.key});

  @override
  State<BuddyNotesScreen> createState() => _BuddyNotesScreenState();
}

class _BuddyNotesScreenState extends State<BuddyNotesScreen> {
  final _ctl = TextEditingController();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final notes = context.read<BuddyNotesService>().notes;
    _ctl.text = notes;
    _ctl.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<BuddyNotesService>().updateNotes(_ctl.text);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Notizen gespeichert ✓', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.success.withOpacity(0.9),
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
      backgroundColor: AppColors.bgDarkest,
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
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.02),
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
                          color: AppColors.glassBg.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Buddy Notizen',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
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
                Text('Hier speichert die KI wichtige Dinge — editierbar',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                  color: AppColors.bgCard.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: _ctl,
                  maxLines: null,
                  minLines: 20,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Notizen...',
                    hintStyle: TextStyle(color: AppColors.textTertiary.withOpacity(0.4)),
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
