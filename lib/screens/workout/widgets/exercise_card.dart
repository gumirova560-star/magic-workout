import 'package:flutter/material.dart';
import '../../../models/exercise.dart';
import '../../../models/workout_day.dart';
import '../widgets/set_row.dart';
import '../../exercise/exercise_detail_screen.dart';

class ExerciseCard extends StatelessWidget {
  final WorkoutExercise item;
  final Exercise ex;
  final int? circleIndex;
  final int? index;
  final bool isViewMode;
  final bool started;
  final List<SetData> sets;
  // 👇 МЕНЯЕМ СИГНАТУРУ НА ПЕРЕДАЧУ ИНДЕКСА
  final void Function(int index, SetData data) onSetChanged;
  final Function() onSetComplete;
  final Function() onAddSet;
  final Function(int) onDeleteSet;
  final Function() onOpenMenu;
  final Function(int) onTryAutoCollapse;

  final String? Function(Exercise) getBaseZone;
  final bool Function(Exercise) isBase;
  final String Function(String) groupLabel;
  final bool Function(Exercise) isCardio;
  final bool Function(String) isTimed;
  final int? Function(String) parseReps;

  const ExerciseCard({
    super.key,
    required this.item,
    required this.ex,
    this.circleIndex,
    this.index,
    required this.isViewMode,
    required this.started,
    required this.sets,
    required this.onSetChanged,
    required this.onSetComplete,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onOpenMenu,
    required this.onTryAutoCollapse,
    required this.getBaseZone,
    required this.isBase,
    required this.groupLabel,
    required this.isCardio,
    required this.isTimed,
    required this.parseReps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCardio = this.isCardio(ex);
    final isTimed = this.isTimed(ex.name);
    final baseZone = getBaseZone(ex);
    final isThisBase = isBase(ex);
    final defaultReps = parseReps(item.reps);

    final List<int> setIndexesToShow = circleIndex != null
        ? (circleIndex! < sets.length ? [circleIndex!] : [])
        : List.generate(sets.length, (i) => i);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: isViewMode ? null : onOpenMenu,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  if (index != null) ...[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCardio
                            ? const [Color(0xFFE17055), Color(0xFFFAB1A0)]
                            : const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(isCardio ? Icons.directions_run_rounded : Icons.fitness_center, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name, style: theme.textTheme.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (!isCardio) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isThisBase)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text('БАЗА - ${groupLabel(baseZone ?? '').toUpperCase()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                                      )
                                    else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('ИЗОЛЯЦИЯ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF00B894))),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ex.muscleGroups.map((g) => groupLabel(g)).join(' + ').toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)));
                          },
                          tooltip: 'Детали упражнения',
                        ),
                      ],
                    ),
                  ),
                  if (!isViewMode) Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                ],
              ),
            ),
            if (ex.description.isNotEmpty && circleIndex == null) ...[
              const SizedBox(height: 10),
              Text(
                ex.description,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            if (setIndexesToShow.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Нет подходов для отображения', style: TextStyle(color: Colors.grey)),
              )
            else
              for (final i in setIndexesToShow)
                SetRow(
                  key: ValueKey('${item.id}_$i'),
                  setNumber: i + 1,
                  setIndex: i, // 👈 ПЕРЕДАЕМ ИНДЕКС ПОДХОДА
                  completed: sets[i].completed,
                  initialWeight: sets[i].weight,
                  initialReps: sets[i].reps ?? defaultReps,
                  readOnly: isViewMode,
                  isCardio: isCardio,
                  isTimed: isTimed,
                  targetReps: item.reps,
                  onChanged: (index, data) { // 👈 ИЗМЕНЕНА СИГНАТУРА
                    if (item.id == null || isViewMode) return;
                    var updatedData = data;
                    if (data.completed && data.reps == null && defaultReps != null) {
                      updatedData = SetData(weight: data.weight, reps: defaultReps, completed: data.completed);
                    }
                    onSetChanged(index, updatedData); // 👈 ПЕРЕДАЕМ ИНДЕКС НАВЕРХ
                    if (circleIndex != null && item.id != null) onTryAutoCollapse(circleIndex!);
                  },
                  onComplete: () {
                    onSetComplete();
                    if (circleIndex != null && item.id != null) onTryAutoCollapse(circleIndex!);
                  },
                  onDelete: circleIndex == null ? () => onDeleteSet(i) : null,
                ),
            if (!isViewMode && started && circleIndex == null && !isCardio)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddSet,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить подход'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}