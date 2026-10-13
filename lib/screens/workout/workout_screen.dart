import 'package:flutter/material.dart';
import '../../data/fairy_mood.dart';
import '../../models/user_profile.dart';
import '../../models/workout_template.dart';
import '../../services/database_helper.dart';
import '../../services/workout_generator.dart';
import '../../services/fairy_reaction_service.dart';
import '../yoga/yoga_screen.dart';
import 'workout_detail_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<UserProfile> _profiles = [];
  UserProfile? _activeProfile;
  List<WorkoutTemplate> _templates = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  //  ЗАГРУЗКА
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final profiles = await DatabaseHelper.instance.getProfiles();

    // Загружаем активный профиль из SharedPreferences
    await FairyReactionService().loadActiveProfile();
    final activeId = FairyReactionService().activeProfileId;

    if (profiles.isNotEmpty) {
      final active = profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => profiles.first,
      );
      final templates =
          await DatabaseHelper.instance.getTemplates(active.id!);
      setState(() {
        _profiles = profiles;
        _activeProfile = active;
        _templates = templates;
        _loading = false;
      });
      // ═══ Передаём gender ═══
      await FairyReactionService().setActiveProfile(
        active.id,
        active.name,
        gender: active.gender,
      );
    } else {
      setState(() {
        _profiles = profiles;
        _activeProfile = null;
        _templates = [];
        _loading = false;
      });
      await FairyReactionService().setActiveProfile(null, null);
    }
  }

  Future<void> _switchProfile(UserProfile profile) async {
    final templates =
        await DatabaseHelper.instance.getTemplates(profile.id!);
    setState(() {
      _activeProfile = profile;
      _templates = templates;
    });
    // ═══ Передаём gender ═══
    await FairyReactionService().setActiveProfile(
      profile.id,
      profile.name,
      gender: profile.gender,
    );
  }

  Future<void> _openTemplate(WorkoutTemplate template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          template: template,
          profileId: _activeProfile!.id!,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openYoga() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YogaScreen()),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ГЕНЕРАЦИЯ ПЛАНА
  // ═══════════════════════════════════════════════════════════

  Future<void> _generatePlan() async {
    if (_activeProfile == null) {
      _showMessage('Сначала создайте профиль');
      return;
    }

    setState(() => _generating = true);

    try {
      // ═══ Передаём gender ═══
      await FairyReactionService().setActiveProfile(
        _activeProfile!.id,
        _activeProfile!.name,
        gender: _activeProfile!.gender,
      );

      final freshProfile = await DatabaseHelper.instance
          .getProfileById(_activeProfile!.id!);

      if (freshProfile == null) {
        setState(() => _generating = false);
        _showMessage('Профиль не найден');
        return;
      }

      setState(() => _activeProfile = freshProfile);

      final oldTemplates =
          await DatabaseHelper.instance.getTemplates(freshProfile.id!);
      for (final t in oldTemplates) {
        await DatabaseHelper.instance.deleteTemplate(t.id!);
      }

      final templates =
          await WorkoutGenerator.generateWeekPlan(freshProfile);

      setState(() {
        _templates = templates;
        _generating = false;
      });

      // ═══ Реакция феи — празднующая ═══
      FairyReactionService().trigger(
        'plan_generated',
        mood: FairyMood.party,
      );
    } catch (e) {
      setState(() => _generating = false);
      _showMessage('Ошибка: $e');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeProfile == null) {
      return _buildNoProfileState(context);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreeting(context),
            const SizedBox(height: 20),
            if (_profiles.length > 1) ...[
              _buildProfileSwitcher(context),
              const SizedBox(height: 20),
            ],
            _buildSectionTitle(context, 'Быстрый старт'),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(context, 'Мой план'),
                if (_templates.isNotEmpty)
                  TextButton.icon(
                    onPressed: _generating ? null : _generatePlan,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Обновить'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPlanContent(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Прогресс за неделю'),
            const SizedBox(height: 12),
            _buildStats(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  UI-БЛОКИ
  // ═══════════════════════════════════════════════════════════

  Widget _buildGreeting(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Привет, ${_activeProfile!.name}!',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.fitness_center,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${_templates.length}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSwitcher(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _profiles.length,
        itemBuilder: (_, i) {
          final p = _profiles[i];
          final isActive = p.id == _activeProfile!.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _switchProfile(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: isActive
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            context,
            icon: Icons.auto_awesome_rounded,
            label: 'Создать план',
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            ),
            onTap: _generating ? null : _generatePlan,
            isLoading: _generating,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            context,
            icon: Icons.self_improvement_rounded,
            label: 'Йога',
            gradient: const LinearGradient(
              colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
            ),
            onTap: _openYoga,
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(BuildContext context) {
    if (_templates.isEmpty) {
      return _buildEmptyPlan(context);
    }

    return Column(
      children: _templates.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _templateCard(context, t),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyPlan(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Плана пока нет',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите «Создать план» — приложение подберёт тренировки под ваш профиль',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generatePlan,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_generating ? 'Создаём...' : 'Создать план'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateCard(BuildContext context, WorkoutTemplate template) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => _openTemplate(template),
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
                  Icons.fitness_center,
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
                      '${template.estimatedMinutes} мин · ${template.typeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
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

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            icon: Icons.calendar_today_rounded,
            value: '0',
            label: 'тренировок',
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.timer_rounded,
            value: '0',
            label: 'минут',
            color: const Color(0xFF00B894),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }

  Widget _buildNoProfileState(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_rounded,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text('Нет профилей', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Создайте профиль во вкладке «Профили»',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}