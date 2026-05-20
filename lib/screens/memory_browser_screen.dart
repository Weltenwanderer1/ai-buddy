import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/memory_service.dart';

class MemoryBrowserScreen extends StatelessWidget {
  const MemoryBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: Consumer<MemoryService>(
        builder: (context, mem, _) {
          return DefaultTabController(
            length: 3,
            child: CustomScrollView(
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
                          AppColors.secondary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.02),
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
                                color: AppColors.glassBg.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text('Erinnerungen',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text('Core ${mem.coreMemories.length}  ·  Langzeit ${mem.longTermMemories.length}  ·  Kurzzeit ${mem.shortTermMemories.length}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              gradient: AppColors.secondaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textSecondary,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Core'),
                              Tab(text: 'Langzeit'),
                              Tab(text: 'Kurzzeit'),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    children: [
                      _buildTier(mem.coreMemories, AppColors.secondary, 'Noch keine Core-Erinnerungen'),
                      _buildTier(mem.longTermMemories, AppColors.primary, 'Noch keine Langzeit-Erinnerungen'),
                      _buildTier(mem.shortTermMemories, AppColors.accent, 'Noch keine Kurzzeit-Erinnerungen'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTier(List<MemoryItem> items, Color color, String emptyText) {
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.memory_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(emptyText, style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
      ]));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              items[i].timestamp.toIso8601String().split('T').first,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(items[i].source,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(items[i].content,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
        ]),
      ),
    );
  }
}
