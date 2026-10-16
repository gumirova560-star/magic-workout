import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/exercise.dart';

/// ⚠️ Экран деталей упражнения.
///
/// Показывает: описание, технику, ошибки, советы.
/// 3 цветные кнопки поиска (сразу под бейджами):
///   ▶ Видео / 🖼 Картинки / 🧬 Анатомия мышц.
class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  // ═══════════════════════════════════════════════════════════
  //  ЦВЕТА И ИКОНКИ ПО ТИПУ УПРАЖНЕНИЯ
  // ═══════════════════════════════════════════════════════════

  bool get _isCardio =>
      exercise.muscleGroups.contains('cardio');

  bool get _isStretch =>
      exercise.muscleGroups.contains('full_body') ||
      exercise.name.toLowerCase().contains('растяж');

  List<Color> get _gradientColors {
    if (_isCardio) {
      return [const Color(0xFFE17055), const Color(0xFFFAB1A0)];
    }
    if (_isStretch) {
      return [const Color(0xFF00B894), const Color(0xFF55EFC4)];
    }
    return [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)];
  }

  IconData get _heroIcon {
    if (_isCardio) return Icons.directions_run_rounded;
    if (_isStretch) return Icons.self_improvement;
    return Icons.fitness_center;
  }

  // ═══════════════════════════════════════════════════════════
  //  ОТКРЫТИЕ ЯНДЕКС-ССЫЛОК
  // ═══════════════════════════════════════════════════════════

  Future<void> _openYandexVideo(BuildContext context) async {
    final query = Uri.encodeComponent(
      '${exercise.name} техника выполнения',
    );
    final url = Uri.parse(
      'https://yandex.ru/video/search?text=$query',
    );
    await _launch(context, url);
  }

  Future<void> _openYandexImages(BuildContext context) async {
    final query = Uri.encodeComponent(
      '${exercise.name} техника выполнения',
    );
    final url = Uri.parse(
      'https://yandex.ru/images/search?text=$query',
    );
    await _launch(context, url);
  }

  Future<void> _openYandexAnatomy(BuildContext context) async {
    final query = Uri.encodeComponent(
      '${exercise.name} анатомия мышц',
    );
    final url = Uri.parse(
      'https://yandex.ru/images/search?text=$query',
    );
    await _launch(context, url);
  }

  Future<void> _launch(BuildContext context, Uri url) async {
    try {
      final ok = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть ссылку'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══ HERO — иконка-плейсхолдер ═══
          _buildHero(theme),
          const SizedBox(height: 16),

          // ═══ Бейджи (группы, сложность, оборудование) ═══
          _buildBadges(theme),
          const SizedBox(height: 20),

          // ⚠️ Кнопки поиска — сразу под бейджами
          _buildSearchButtons(context, theme),
          const SizedBox(height: 24),

          // ═══ Описание ═══
          if (exercise.description.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.article_rounded,
              title: 'Описание',
              color: const Color(0xFF6C5CE7),
              child: Text(
                exercise.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),

          // ═══ Техника ═══
          if (exercise.technique.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.rule_rounded,
              title: 'Техника выполнения',
              color: const Color(0xFF00B894),
              child: Text(
                exercise.technique,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),

          // ═══ Ошибки ═══
          if (exercise.mistakes.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.warning_amber_rounded,
              title: 'Частые ошибки',
              color: const Color(0xFFE17055),
              child: Text(
                exercise.mistakes,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),

          // ═══ Советы ═══
          if (exercise.tips.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.tips_and_updates_rounded,
              title: 'Советы',
              color: const Color(0xFFFDCB6E),
              child: Text(
                exercise.tips,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HERO
  // ═══════════════════════════════════════════════════════════

  Widget _buildHero(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _gradientColors.first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(_heroIcon, size: 80, color: Colors.white),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  БЕЙДЖИ
  // ═══════════════════════════════════════════════════════════

  Widget _buildBadges(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (exercise.muscleGroups.isNotEmpty)
          _badge(
            theme,
            icon: Icons.fitness_center,
            label: exercise.muscleGroups
                .where((g) => g != 'cardio')
                .map(_muscleLabel)
                .join(' · '),
            color: const Color(0xFF6C5CE7),
          ),
        if (_isCardio)
          _badge(
            theme,
            icon: Icons.favorite_rounded,
            label: 'Кардио',
            color: const Color(0xFFE17055),
          ),
        _badge(
          theme,
          icon: Icons.signal_cellular_alt_rounded,
          label: exercise.difficultyLabel,
          color: _difficultyColor(exercise.difficulty),
        ),
        if (exercise.equipment.isNotEmpty)
          _badge(
            theme,
            icon: Icons.construction_rounded,
            label: exercise.equipment.map(_equipmentLabel).join(' · '),
            color: const Color(0xFF00B894),
          ),
      ],
    );
  }

  Widget _badge(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  СЕКЦИЯ
  // ═══════════════════════════════════════════════════════════

  Widget _section(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  КНОПКИ ПОИСКА — 3 цветные кнопки в ряд
  // ═══════════════════════════════════════════════════════════

  Widget _buildSearchButtons(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Найти в интернете',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _searchChip(
                context,
                icon: Icons.play_circle_filled_rounded,
                label: 'Видео',
                color: const Color(0xFFE17055),
                onTap: () => _openYandexVideo(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _searchChip(
                context,
                icon: Icons.image_rounded,
                label: 'Картинки',
                color: const Color(0xFF6C5CE7),
                onTap: () => _openYandexImages(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _searchChip(
                context,
                icon: Icons.accessibility_new_rounded,
                label: 'Анатомия',
                color: const Color(0xFF00B894),
                onTap: () => _openYandexAnatomy(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ⚠️ Компактная цветная кнопка поиска.
  ///
  /// — каждая своего цвета;
  /// — FittedBox подгоняет текст, если не влезает.
  Widget _searchChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ЛЕЙБЛЫ
  // ═══════════════════════════════════════════════════════════

  String _muscleLabel(String code) {
    const map = {
      'glutes': 'ягодицы',
      'abs': 'пресс',
      'obliques': 'косые',
      'arms': 'руки',
      'biceps': 'бицепс',
      'triceps': 'трицепс',
      'shoulders': 'плечи',
      'legs': 'ноги',
      'quads': 'бёдра',
      'hamstrings': 'задняя поверхность',
      'calves': 'голень',
      'back': 'спина',
      'lats': 'широчайшие',
      'traps': 'трапеции',
      'lower_back': 'поясница',
      'chest': 'грудь',
      'core': 'кор',
      'forearms': 'предплечья',
      'rotator_cuff': 'ротаторная манжета',
      'full_body': 'всё тело',
      'cardio': 'кардио',
    };
    return map[code] ?? code;
  }

  String _equipmentLabel(String code) {
    const map = {
      'barbell': 'штанга',
      'dumbbells': 'гантели',
      'bodyweight': 'своё тело',
      'bench': 'скамья',
      'machine': 'тренажёр',
      'cable': 'блок',
      'resistance_band': 'резинка',
      'jump_rope': 'скакалка',
    };
    return map[code] ?? code;
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return const Color(0xFF00B894);
      case 'intermediate':
        return const Color(0xFFFDCB6E);
      case 'advanced':
        return const Color(0xFFE17055);
      default:
        return const Color(0xFF6C5CE7);
    }
  }
}
// ═══ ФАЙЛ exercise_detail_screen.dart ЗАВЕРШЁН ═══