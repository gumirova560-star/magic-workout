import 'package:flutter/material.dart';
import '../../models/yoga_session.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import '../../data/fairy_mood.dart';
import '../../widgets/fairy_bubble.dart';
import 'session_detail_screen.dart';
import 'stretch_list_screen.dart';

class YogaScreen extends StatefulWidget {
  const YogaScreen({super.key});

  @override
  State<YogaScreen> createState() => _YogaScreenState();
}

class _YogaScreenState extends State<YogaScreen> {
  List<YogaSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Блокируем фразы, пока грузятся данные
    FairyReactionService().holdScreenPhrases();

    _loadSessions().then((_) {
      if (!mounted) return;

      FairyReactionService().releaseScreenPhrases();

      // Задержка для 100% удаления старого пузыря
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          FairyReactionService().say(
            'Дыши глубже, расслабься и почувствуй свое тело 🧘‍♀️',
            mood: FairyMood.yoga,
          );
        }
      });
    });
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await DatabaseHelper.instance.getYogaSessions();
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _openSession(YogaSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
    );
  }

  void _openFreeStretch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StretchListScreen()),
    );
  }

  IconData _getFocusIcon(String focus) {
    switch (focus) {
      case 'back': return Icons.accessibility_new_rounded;
      case 'flexibility': return Icons.self_improvement_rounded;
      case 'relax': return Icons.spa_rounded;
      case 'glutes': return Icons.directions_walk_rounded;
      case 'morning': return Icons.wb_sunny_rounded;
      case 'core': return Icons.fitness_center_rounded;
      default: return Icons.self_improvement;
    }
  }

  Color _getFocusColor(String focus) {
    switch (focus) {
      case 'back': return const Color(0xFF6C5CE7);
      case 'flexibility': return const Color(0xFF00B894);
      case 'relax': return const Color(0xFF81ECEC);
      case 'glutes': return const Color(0xFFE84393);
      case 'morning': return const Color(0xFFFDCB6E);
      case 'core': return const Color(0xFFE17055);
      default: return const Color(0xFF6C5CE7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Йога и растяжка')),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFreePracticeCard(context),
                      const SizedBox(height: 20),
                      Text(
                        'Готовые сессии',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_sessions.length} практик для разных целей',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sessions.map((s) => _buildSessionCard(context, s)),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
          const FairyBubble(screenKey: 'yoga'),
        ],
      ),
    );
  }

  Widget _buildFreePracticeCard(BuildContext context) {
    return GestureDetector(
      onTap: _openFreeStretch,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Свободная практика',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Выбери позы и растяжки вручную',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, YogaSession session) {
    final theme = Theme.of(context);
    final color = _getFocusColor(session.focus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openSession(session),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getFocusIcon(session.focus),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '${session.durationMinutes} мин',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
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
  }
}