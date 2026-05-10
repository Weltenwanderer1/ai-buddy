import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/self_identity_service.dart';

/// Screen to view and edit the AI's self-identity ("Ich").
/// The KI evolves this autonomously, but the user can view and adjust it.
class SelfIdentityScreen extends StatefulWidget {
  const SelfIdentityScreen({super.key});

  @override
  State<SelfIdentityScreen> createState() => _SelfIdentityScreenState();
}

class _SelfIdentityScreenState extends State<SelfIdentityScreen> {
  final _nameCtl = TextEditingController();
  final _essenceCtl = TextEditingController();
  final _relationshipCtl = TextEditingController();
  final _emotionCtl = TextEditingController();
  final _purposeCtl = TextEditingController();

  List<String> _rules = [];
  List<String> _goals = [];
  List<String> _experiences = [];

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadFromService();
  }

  void _loadFromService() {
    final self = context.read<SelfIdentityService>();
    _nameCtl.text = self.name;
    _essenceCtl.text = self.essence;
    _relationshipCtl.text = self.relationshipDescription;
    _emotionCtl.text = self.emotionalTone;
    _purposeCtl.text = self.purpose;
    _rules = List.from(self.behaviorRules);
    _goals = List.from(self.ongoingGoals);
    _experiences = List.from(self.keyExperiences);
  }

  Future<void> _save() async {
    final self = context.read<SelfIdentityService>();
    await self.updateName(_nameCtl.text);
    await self.updateEssence(_essenceCtl.text);
    await self.updateRelationship(_relationshipCtl.text);
    await self.updateEmotionalTone(_emotionCtl.text);
    await self.updatePurpose(_purposeCtl.text);
    await self.updateBehaviorRules(_rules);
    await self.updateOngoingGoals(_goals);
    setState(() => _isEditing = false);
    _showSnack('Selbstbild gespeichert ✓', AppColors.success);
  }

  void _showSnack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: c.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: Consumer<SelfIdentityService>(
        builder: (context, self, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.secondary.withOpacity(0.2),
                        AppColors.secondary.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.glassBg.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.glassBorder.withOpacity(0.3),
                                  ),
                                ),
                                child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Selbstbild',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_isEditing) {
                                  _save();
                                } else {
                                  setState(() => _isEditing = true);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.secondaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isEditing ? 'Speichern' : 'Bearbeiten',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.secondaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.psychology_rounded, size: 36, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        self.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Letzte autonome Anpassung: ${_formatDate(self.lastAutoUpdate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCard(
                        title: 'Wesen / Essenz',
                        icon: Icons.bubble_chart_rounded,
                        child: _isEditing
                            ? _buildTextField(_essenceCtl, maxLines: 3)
                            : Text(self.essence, style: _bodyStyle()),
                      ),

                      _buildCard(
                        title: 'Verhaltensregeln',
                        icon: Icons.gavel_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _isEditing
                              ? _buildEditableList(_rules, (v) => _rules = v)
                              : self.behaviorRules.map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(child: Text(r, style: _bodyStyle())),
                                    ],
                                  ),
                                )).toList(),
                        ),
                      ),

                      _buildCard(
                        title: 'Beziehung',
                        icon: Icons.favorite_rounded,
                        child: _isEditing
                            ? _buildTextField(_relationshipCtl, maxLines: 3)
                            : Text(self.relationshipDescription, style: _bodyStyle()),
                      ),

                      _buildCard(
                        title: 'Emotionale Grundstimmung',
                        icon: Icons.wb_sunny_rounded,
                        child: _isEditing
                            ? _buildTextField(_emotionCtl)
                            : Text(self.emotionalTone, style: _bodyStyle()),
                      ),

                      _buildCard(
                        title: 'Sinn / Zweck',
                        icon: Icons.auto_awesome_rounded,
                        child: _isEditing
                            ? _buildTextField(_purposeCtl, maxLines: 3)
                            : Text(self.purpose, style: _bodyStyle()),
                      ),

                      _buildCard(
                        title: 'Aktuelle Ziele',
                        icon: Icons.flag_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _isEditing
                              ? _buildEditableList(_goals, (v) => _goals = v)
                              : self.ongoingGoals.map((g) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(child: Text(g, style: _bodyStyle())),
                                    ],
                                  ),
                                )).toList(),
                        ),
                      ),

                      if (self.keyExperiences.isNotEmpty)
                        _buildCard(
                          title: 'Erfahrungen',
                          icon: Icons.history_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: self.keyExperiences.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.glassBorder.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(e, style: _bodyStyle()),
                              ),
                            )).toList(),
                          ),
                        ),

                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Dieses Selbstbild entwickelt sich autonom.\nDu kannst es hier ansehen und anpassen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctl, {int maxLines = 1}) {
    return TextField(
      controller: ctl,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintStyle: TextStyle(color: AppColors.textTertiary.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.bgCard.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.secondary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  List<Widget> _buildEditableList(List<String> items, void Function(List<String>) onChanged) {
    return [
      ...items.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: entry.value),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgCard.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) {
                    items[entry.key] = v;
                    onChanged(items);
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  items.removeAt(entry.key);
                  onChanged(items);
                  setState(() {});
                },
                child: Icon(Icons.remove_circle, color: AppColors.error, size: 20),
              ),
            ],
          ),
        );
      }).toList(),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () {
          items.add('');
          onChanged(items);
          setState(() {});
        },
        child: Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.secondary, size: 20),
            const SizedBox(width: 8),
            Text('Hinzufügen', style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ];
  }

  TextStyle _bodyStyle() => TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
    height: 1.6,
    fontWeight: FontWeight.w400,
  );

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
