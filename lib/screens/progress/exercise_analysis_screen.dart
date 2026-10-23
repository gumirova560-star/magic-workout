import 'package:flutter/material.dart';
import '../../data/fairy_mood.dart';
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

    final trends = await WeekAnalyzer.analyzeExerciseTrends(profiles.first.id!);

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
                  child: _buildGroupedList(context),
                ),
    );
  }

  // 👇 ГРУППИРОВКА СПИСКА
  Widget _buildGroupedList(BuildContext context) {
    final weightTrends = _trends.where((t) => t.isWeightBased).toList();
    final functionalTrends = _trends.where((t) => !t.isWeightBased).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (weightTrends.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Силовой прогресс',
            subtitle: 'Упражнения с весом (кг)',
            icon: Icons.fitness_center_rounded,
            color: const Color(0xFF6C5CE7),
          ),
          ...weightTrends.map((t) => _buildTrendCard(context, t)),
        ],

        if (weightTrends.isNotEmpty && functionalTrends.isNotEmpty)
          const SizedBox(height: 24),

        if (functionalTrends.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Функциональный прогресс',
            subtitle: 'Время / повторения / кардио',
            icon: Icons.timer_rounded,
            color: const Color(0xFF00B894),
          ),
          ...functionalTrends.map((t) => _buildTrendCard(context, t)),
        ],
      ],
    );
  }

  // 👇 ЗАГОЛОВОК СЕКЦИИ
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
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
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    final text = value != null ? '${_formatValue(value)} $unit' : '—';

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

  // 👇 ОБНОВЛЕННАЯ ЗАГЛУШКА С ФЕЕЙ
  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              FairyMood.think.asset,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.insights_rounded,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Идет анализ...',
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ждем завершения 3-й недели текущего цикла, чтобы сравнить результаты с 1-й неделей и показать твой прогресс.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}