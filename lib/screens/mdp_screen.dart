import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/buddy_colors.dart';
import '../services/mdp_service.dart';

/// Medication schedule screen (MDP = Medikamentenplan).
class MdpScreen extends StatefulWidget {
  const MdpScreen({super.key});

  @override
  State<MdpScreen> createState() => _MdpScreenState();
}

class _MdpScreenState extends State<MdpScreen> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
  bool _showAddForm = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _timeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('💊 Medikamentenplan'),
        backgroundColor: c.card,
        foregroundColor: c.t1,
        actions: [
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.add, color: c.accent),
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
          ),
        ],
      ),
      body: Consumer<MdpService>(
        builder: (context, mdp, _) {
          final due = mdp.dueToday;
          final taken = mdp.takenToday;
          final allActive = mdp.activeEntries;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add form
                if (_showAddForm) _buildAddForm(c),

                // Due today
                Text('🕐 Heute fällig', style: TextStyle(color: c.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (due.isEmpty && taken.isEmpty)
                  _EmptyTile(c, '✅ Alle Medikamente für heute erledigt!')
                else ...[
                  if (due.isNotEmpty)
                    ...due.map((e) => _MdpTile(
                      entry: e,
                      c: c,
                      onTake: () => _take(e.id),
                      onSkip: () => _skip(e.id),
                    )),
                  if (taken.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('✅ Bereits genommen', style: TextStyle(color: c.t3, fontSize: 13)),
                    const SizedBox(height: 4),
                    ...taken.map((e) => _MdpTile(
                      entry: e,
                      c: c,
                      taken: true,
                      onUndo: () => _undo(e.id),
                    )),
                  ],
                ],

                const SizedBox(height: 24),
                Text('📋 Alle aktiven Medikamente', style: TextStyle(color: c.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (allActive.isEmpty)
                  _EmptyTile(c, 'Noch keine Medikamente hinterlegt.')
                else
                  ...allActive.map((e) => _MdpListTile(entry: e, c: c, mdp: mdp)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddForm(c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neues Medikament', style: TextStyle(color: c.t1, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _Field(c, _nameCtrl, 'Name (z.B. Vitamin D3)', Icons.medication),
          const SizedBox(height: 8),
          _Field(c, _dosageCtrl, 'Dosierung (z.B. 1000 IE)', Icons.speed),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _selectedTime);
              if (picked != null) {
                setState(() {
                  _selectedTime = picked;
                  _timeCtrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                });
              }
            },
            child: IgnorePointer(
              child: _Field(c, _timeCtrl, 'Uhrzeit', Icons.schedule, controllerText: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Wochentage', style: TextStyle(color: c.t2, fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(MdpEntry.weekdayLabels[day], style: TextStyle(fontSize: 12, color: selected ? Colors.white : c.t1)),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) _selectedDays.add(day);
                    else _selectedDays.remove(day);
                  });
                },
                selectedColor: c.accent,
                backgroundColor: c.elev,
                checkmarkColor: Colors.white,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }),
          ),
          const SizedBox(height: 8),
          _Field(c, _noteCtrl, 'Notiz (optional)', Icons.note),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Speichern'),
              style: FilledButton.styleFrom(backgroundColor: c.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _saveEntry() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedDays.isEmpty) return;

    final time = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_$name';

    final entry = MdpEntry(
      id: id,
      name: name,
      dosage: _dosageCtrl.text.trim(),
      time: time,
      weekdays: List.from(_selectedDays),
      note: _noteCtrl.text.trim(),
      createdAt: now,
    );

    context.read<MdpService>().addEntry(entry);

    _nameCtrl.clear();
    _dosageCtrl.clear();
    _noteCtrl.clear();
    _selectedTime = const TimeOfDay(hour: 8, minute: 0);
    _selectedDays = [1, 2, 3, 4, 5, 6, 7];
    setState(() => _showAddForm = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('💊 "$name" wurde hinzugefügt (täglich um $time)'),
      backgroundColor: Colors.green.withValues(alpha: 0.8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _take(String id) {
    context.read<MdpService>().markTaken(id);
  }

  void _skip(String id) {
    context.read<MdpService>().removeEntry(id);
  }

  void _undo(String id) {
    context.read<MdpService>().markNotTaken(id);
  }
}

class _Field extends StatelessWidget {
  final c;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? controllerText;

  const _Field(this.c, this.controller, this.hint, this.icon, {this.controllerText});

  @override
  Widget build(BuildContext context) {
    if (controllerText != null && controller.text.isEmpty) {
      controller.text = controllerText!;
    }
    return TextField(
      controller: controller,
      style: TextStyle(color: c.t1, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.t3, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: c.t3),
        filled: true,
        fillColor: c.elev,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final c;
  final String text;
  const _EmptyTile(this.c, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: c.t3, fontSize: 14)),
      ),
    );
  }
}

class _MdpTile extends StatelessWidget {
  final MdpEntry entry;
  final c;
  final bool taken;
  final VoidCallback? onTake;
  final VoidCallback? onSkip;
  final VoidCallback? onUndo;

  const _MdpTile({
    required this.entry,
    required this.c,
    this.taken = false,
    this.onTake,
    this.onSkip,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: taken ? Colors.green.withValues(alpha: 0.1) : c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: taken ? Colors.green.withValues(alpha: 0.3) : c.border),
      ),
      child: Row(
        children: [
          Icon(taken ? Icons.check_circle : Icons.medication, color: taken ? Colors.green : c.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: TextStyle(color: c.t1, fontSize: 15, fontWeight: FontWeight.w600)),
                Text('${entry.dosage} • ${entry.time} Uhr', style: TextStyle(color: c.t3, fontSize: 13)),
                if (entry.note.isNotEmpty) Text(entry.note, style: TextStyle(color: c.t2, fontSize: 12)),
              ],
            ),
          ),
          if (taken)
            TextButton(onPressed: onUndo, child: Text('Rückgängig', style: TextStyle(color: c.t3, fontSize: 12)))
          else ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              tooltip: 'Genommen',
              onPressed: onTake,
            ),
          ],
        ],
      ),
    );
  }
}

class _MdpListTile extends StatelessWidget {
  final MdpEntry entry;
  final c;
  final MdpService mdp;

  const _MdpListTile({required this.entry, required this.c, required this.mdp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: TextStyle(color: c.t1, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  '${entry.dosage} • ${entry.time} • ${entry.weekdayLabel}',
                  style: TextStyle(color: c.t3, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.error, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Entfernen?'),
                  content: Text('${entry.name} wirklich löschen?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                    TextButton(onPressed: () {
                      mdp.removeEntry(entry.id);
                      Navigator.pop(ctx);
                    }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
