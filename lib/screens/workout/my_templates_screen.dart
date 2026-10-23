import 'package:flutter/material.dart';
import '../../models/workout_template.dart';
import '../../models/workout_day.dart'; // ⚠️ Импорт WorkoutDay
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'workout_detail_screen.dart';

class MyTemplatesScreen extends StatefulWidget {
  final int profileId;

  const MyTemplatesScreen({
    super.key,
    required this.profileId,
  });

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  List<WorkoutTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    FairyReactionService().addWorkoutListener(_onWorkoutCompleted);
  }

  void _onWorkoutCompleted() {
    if (!mounted) return;
    _loadTemplates();
  }

  @override
  void dispose() {
    FairyReactionService().removeWorkoutListener(_onWorkoutCompleted);
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);

    final list = await DatabaseHelper.instance
        .getCustomTemplates(widget.profileId);

    if (!mounted) return;
    setState(() {
      _templates = list;
      _loading = false;
    });
  }

  Future<void> _openTemplate(WorkoutTemplate template) async {
    // ⚠️ Создаем временный WorkoutDay из шаблона
    final newDay = WorkoutDay(
      profileId: widget.profileId,
      templateId: template.id,
      name: template.name,
      type: template.type,
      status: 'planned',
      date: DateTime.now(),
    );

    final newDayId = await DatabaseHelper.instance.createWorkoutDay(newDay);
    final savedDay = newDay.copyWith(id: newDayId);

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workoutDay: savedDay, // ⚠️ Передаем WorkoutDay
          profileId: widget.profileId,
        ),
      ),
    );

    if (result == true && mounted) _loadTemplates();
  }

  Future<void> _deleteTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text(
          'Шаблон «${template.name}» будет удалён. '
          'Завершённые тренировки по нему останутся в Истории.',
        ),
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
    );

    if (confirmed != true) return;
    if (template.id == null) return;

    await DatabaseHelper.instance.deleteTemplate(template.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Шаблон «${template.name}» удалён'),
        duration: const Duration(seconds: 2),
      ),
    );

    _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои шаблоны'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTemplates,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _templates.isEmpty
                ? _buildEmptyState(context)
                : _buildList(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нет шаблонов',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Завершите тренировку и нажмите '
                    '«Сохранить как шаблон» — она появится здесь.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _buildHeader(context);
        return _templateCard(context, _templates[i - 1]);
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_templates.length} ${_plural(_templates.length)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _plural(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'шаблон';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'шаблона';
    }
    return 'шаблонов';
  }

  Widget _templateCard(BuildContext context, WorkoutTemplate template) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openTemplate(template),
        onLongPress: () => _deleteTemplate(template),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bookmark_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.estimatedMinutes} мин · '
                      '${template.typeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () => _deleteTemplate(template),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error.withOpacity(0.7),
                ),
                tooltip: 'Удалить шаблон',
              ),
            ],
          ),
        ),
      ),
    );
  }
}