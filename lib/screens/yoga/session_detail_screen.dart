import 'package:flutter/material.dart';
import '../../models/stretch.dart';
import '../../models/yoga_session.dart';
import '../../services/database_helper.dart';
import '../exercise/stretch_detail_screen.dart'; // ⚠️ Экран деталей
import 'yoga_player_screen.dart'; // ⚠️ Экран таймера

/// ⚠️ Экран деталей сессии йоги.
/// Показывает список асан с описанием и кнопкой «Как выполнить».
/// Внизу — кнопка «Начать практику», запускающая таймер.
class SessionDetailScreen extends StatefulWidget {
  final YogaSession session;
  final int? profileId;

  const SessionDetailScreen({
    super.key,
    required this.session,
    this.profileId,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<YogaStep> _steps = [];
  Map<int, Stretch> _stretchMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    setState(() => _loading = true);
    final steps =
        await DatabaseHelper.instance.getYogaSteps(widget.session.id!);

    final map = <int, Stretch>{};
    for (final step in steps) {
      final st = await DatabaseHelper.instance.getStretchById(step.stretchId);
      if (st != null) map[step.stretchId] = st;
    }

    setState(() {
      _steps = steps;
      _stretchMap = map;
      _loading = false;
    });
  }

  void _startSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YogaPlayerScreen(
          session: widget.session,
          profileId: widget.profileId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _steps.isEmpty
              ? _buildEmpty(context)
              : Column(
                  children: [
                    // ═══ Шапка с описанием сессии ═══
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.session.durationMinutes} мин · ${_steps.length} асан',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ═══ Список асан ═══
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _steps.length,
                        itemBuilder: (_, i) =>
                            _buildStepCard(context, _steps[i], i),
                      ),
                    ),

                    // ═══ Кнопка «Начать» ═══
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startSession,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Начать практику'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B894),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStepCard(
      BuildContext context, YogaStep step, int index) {
    final theme = Theme.of(context);
    final stretch = _stretchMap[step.stretchId];
    if (stretch == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Номер асаны
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stretch.name,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stretch.durationLabel}${stretch.bothSides ? " · 2 стороны" : ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ═══ Кнопка «Как выполнить» ═══
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StretchDetailScreen(
                      stretch: stretch,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('Как выполнить'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // ═══ Заметки к асане (если есть) ═══
            if (step.notes != null && step.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
              Icons.self_improvement_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text('Сессия пуста',
                style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'В этой практике ещё нет упражнений',
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