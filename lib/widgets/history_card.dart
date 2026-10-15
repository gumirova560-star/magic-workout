import 'package:flutter/material.dart';
import '../models/workout_day.dart';

class HistoryCard extends StatelessWidget {
  final WorkoutDay workout;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  /// ⚠️ Вычислено снаружи (в HistoryScreen):
  ///    0 < doneSets < totalSets → true (частично выполнен).
  final bool isPartial;

  const HistoryCard({
    super.key,
    required this.workout,
    required this.onTap,
    this.onDelete,
    this.isPartial = false,
  });

  String _formatDate(DateTime date) {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = workout.status == 'completed';
    final isYoga = workout.type == 'yoga';

    // ⚠️ Три состояния:
    //    completed      → зелёный
    //    partial        → оранжевый («Не до конца»)
    //    in_progress(0) → жёлтый / голубой (для йоги)
    final List<Color> gradientColors;
    final IconData iconData;
    final Color accentColor;
    final String badgeText;

    if (isCompleted) {
      gradientColors = [const Color(0xFF00B894), const Color(0xFF55EFC4)];
      iconData = Icons.check_circle_rounded;
      accentColor = const Color(0xFF00B894);
      badgeText = 'Завершена';
    } else if (isPartial) {
      gradientColors = [const Color(0xFFE17055), const Color(0xFFFDCB6E)];
      iconData = Icons.hourglass_bottom_rounded;
      accentColor = const Color(0xFFE17055);
      badgeText = 'Не до конца';
    } else if (isYoga) {
      gradientColors = [const Color(0xFF81ECEC), const Color(0xFFB2F5EA)];
      iconData = Icons.self_improvement_rounded;
      accentColor = const Color(0xFF00B894);
      badgeText = workout.statusLabel;
    } else {
      gradientColors = [const Color(0xFFFDCB6E), const Color(0xFFFFEAA7)];
      iconData = Icons.timer_rounded;
      accentColor = const Color(0xFFFDCB6E);
      badgeText = workout.statusLabel;
    }

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ═══ Иконка ═══
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ Название + бейдж «Йога» ═══
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            workout.name,
                            style: theme.textTheme.headlineMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isYoga) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B894)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.self_improvement_rounded,
                                  size: 10,
                                  color: Color(0xFF00B894),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Йога',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00B894),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(workout.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (workout.durationMinutes != null) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${workout.durationMinutes} мин',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete == null) return card;

    return Dismissible(
      key: ValueKey('history_${workout.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить тренировку?'),
                content: Text('«${workout.name}» будет удалена.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Удалить',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: card,
    );
  }
}