import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/todo_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Shows the full todo list with inline toggle, delete, and add.
/// Mirror of the AI-managed list — user edits sync both ways.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _addCtl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<TodoService>().addListener(_onChange);
  }

  @override
  void dispose() {
    context.read<TodoService>().removeListener(_onChange);
    _addCtl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _add() {
    final text = _addCtl.text.trim();
    if (text.isEmpty) return;
    context.read<TodoService>().add(text);
    _addCtl.clear();
    HapticFeedback.lightImpact();
  }

  void _toggle(String id) {
    context.read<TodoService>().toggle(id);
    HapticFeedback.selectionClick();
  }

  void _delete(String id) {
    context.read<TodoService>().remove(id);
    HapticFeedback.mediumImpact();
  }

  Future<void> _clearAll() async {
    final todoService = context.read<TodoService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.buddy.card,
        title: Text('Alle Todos löschen?', style: TextStyle(color: context.buddy.t1)),
        content: Text('Das kann nicht rückgängig gemacht werden.', style: TextStyle(color: context.buddy.t2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: TextStyle(color: context.buddy.t3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Alle löschen', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await todoService.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final todo = context.watch<TodoService>();
    final items = todo.items;

    return Scaffold(
      backgroundColor: context.buddy.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.02),
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
                    Expanded(
                      child: Text('Todo-Liste',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.buddy.t1)),
                    ),
                    if (items.isNotEmpty)
                      GestureDetector(
                        onTap: _clearAll,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.buddy.card.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.buddy.border.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.delete_sweep_rounded, color: context.buddy.t3, size: 20),
                        ),
                      ),
                  ]),
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '${todo.pendingCount} offen · ${items.length} gesamt',
                      style: TextStyle(fontSize: 13, color: context.buddy.t3),
                    ),
                  ),
              ]),
            ),
          ),
          // Add input
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: context.buddy.card.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addCtl,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _add(),
                        style: TextStyle(color: context.buddy.t1, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Neues Todo...',
                          hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.4)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _addCtl.text.trim().isEmpty ? null : _add,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: _addCtl.text.trim().isEmpty ? null : AppColors.primaryGradient,
                          color: _addCtl.text.trim().isEmpty ? context.buddy.card.withValues(alpha: 0.3) : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: _addCtl.text.trim().isEmpty ? context.buddy.t3.withValues(alpha: 0.3) : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // List
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 48, color: context.buddy.t3.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('Keine Todos', style: TextStyle(fontSize: 16, color: context.buddy.t3)),
                    const SizedBox(height: 4),
                    Text('Sag mir einfach was zu tun ist!',
                      style: TextStyle(fontSize: 13, color: context.buddy.t3.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final item = items[idx];
                  return _TodoRow(
                    item: item,
                    onToggle: () => _toggle(item.id),
                    onDelete: () => _delete(item.id),
                  );
                },
                childCount: items.length,
              ),
            ),
          // Bottom padding for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoRow({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: context.buddy.card.withValues(alpha: item.done ? 0.25 : 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.buddy.border.withValues(alpha: item.done ? 0.1 : 0.3),
          ),
        ),
        child: Row(
          children: [
            // Checkbox / toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  item.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: item.done ? AppColors.success : context.buddy.t3,
                  size: 24,
                ),
              ),
            ),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  item.text,
                  style: TextStyle(
                    color: item.done ? context.buddy.t3.withValues(alpha: 0.5) : context.buddy.t1,
                    fontSize: 15,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    decorationColor: context.buddy.t3.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Delete
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Icon(Icons.close_rounded, color: context.buddy.t3.withValues(alpha: 0.4), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
