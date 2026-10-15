import 'package:flutter/material.dart';
import '../../services/database_helper.dart';
import '../../services/week_analyzer.dart';

/// Экран «Анализ упражнений» — тренды по каждому упражнению.
class ExerciseAnalysisScreen extends StatefulWidget {
  const ExerciseAnalysisScreen({super.key});

  @override
  State<ExerciseAnalysisScreen> createState() =>
      _ExerciseAnalysisScreenState();
}

class _ExerciseAnalysisScreenState extends State<ExerciseAnalysisScreen> {
  List<ExerciseTrend> _trends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _trends = [];
        _loading = false;
      });
      return;
    }

    final trends =
        await WeekAnalyzer.analyzeExerciseTrends(profiles.first.id!);

    if (!mounted) return;
    setState(() {
      _trends = trends;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ упражнений'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trends.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trends.length,
                    itemBuilder: (_, i) =>
                        _buildTrendCard(context, _trends[i]),
                  ),
                ),
    );
  }

  Widget _buildTrendCard(BuildContext context, ExerciseTrend trend) {
    final theme = Theme.of(context);
    final color = Color(trend.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Название + иконка ═══
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      trend.iconEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trend.exerciseName,
                        style: theme.textTheme.headlineMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Использовано: ${trend.timesUsed} раз',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ═══ Значения ═══
            Row(
              children: [
                Expanded(
                  child: _valueBlock(
                    context,
                    label: 'Прошлая неделя',
                    value: trend.avgValuePrevWeek,
                    unit: trend.unit,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  size: 18,
                ),
                Expanded(
                  child: _valueBlock(
                    context,
                    label: 'Эта неделя',
                    value: trend.avgValueThisWeek,
                    unit: trend.unit,
                    color: color,
                    bold: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ═══ Рекомендация ═══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trend.recommendation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueBlock(
    BuildContext context, {
    required String label,
    required double? value,
    required String unit,
    required Color color,
    bool bold = false,
  }) {
    final theme = Theme.of(context);
    final text = value != null
        ? '${_formatValue(value)} $unit'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  /// Форматирование: 12.5 → «12.5», 12.0 → «12».
  String _formatValue(double v) {
    if (v.truncateToDouble() == v) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(1);
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет данных',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Анализ появится после 2+ тренировок\nс одним упражнением',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}