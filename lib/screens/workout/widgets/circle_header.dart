import 'package:flutter/material.dart';
import '../../../models/workout_day.dart'; // 👈 Добавили импорт

class CircleHeader extends StatelessWidget {
  final int blockNum;
  final int circleNum;
  final int circleIndex;
  final List<WorkoutExercise> blockItems;
  final int completed;
  final int total;
  final bool isComplete;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final bool started;
  final bool isViewMode;
  final Function(int, int) onMarkCircleCompleted;

  const CircleHeader({
    super.key,
    required this.blockNum,
    required this.circleNum,
    required this.circleIndex,
    required this.blockItems,
    required this.completed,
    required this.total,
    required this.isComplete,
    required this.isCollapsed,
    required this.onToggle,
    required this.started,
    required this.isViewMode,
    required this.onMarkCircleCompleted,
  });

  static const List<List<Color>> _blockPalettes = [
    [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    [Color(0xFFE17055), Color(0xFFFAB1A0)],
    [Color(0xFFE84393), Color(0xFFFD79A8)],
    [Color(0xFF0984E3), Color(0xFF74B9FF)],
    [Color(0xFFFDCB6E), Color(0xFFF9E79F)],
  ];

  @override
  Widget build(BuildContext context) {
    final showActions = started && !isViewMode;
    final canMarkAll = showActions && !isComplete;
    final gradientColors = isComplete
        ? const [Color(0xFF00B894), Color(0xFF55EFC4)]
        : _blockPalettes[(blockNum - 1) % _blockPalettes.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: gradientColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Icon(isComplete ? Icons.check_circle_rounded : Icons.fitness_center, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'БЛОК $blockNum — КРУГ $circleNum · $completed/$total',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (canMarkAll)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton.icon(
                    onPressed: () => onMarkCircleCompleted(blockNum, circleIndex),
                    icon: const Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                    label: const Text('Весь круг', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Icon(
                    isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}