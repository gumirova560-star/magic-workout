import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/stretch.dart';

/// ⚠️ Экран деталей растяжки (заминки / йоги).
///
/// Показывает: описание, технику, пользу.
/// 3 кнопки поиска: Видео / Картинки / Анатомия мышц.
class StretchDetailScreen extends StatelessWidget {
  final Stretch stretch;

  const StretchDetailScreen({
    super.key,
    required this.stretch,
  });

  // ═══════════════════════════════════════════════════════════
  //  ЦВЕТА И ИКОНКИ
  // ═══════════════════════════════════════════════════════════

  bool get _isYoga => stretch.category == 'yoga';

  List<Color> get _gradientColors {
    if (_isYoga) {
      return [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)];
    }
    return [const Color(0xFF00B894), const Color(0xFF55EFC4)];
  }

  IconData get _heroIcon {
    if (_isYoga) return Icons.self_improvement;
    return Icons.accessibility_new_rounded;
  }

  // ═══════════════════════════════════════════════════════════
  //  ⚠️ КОНТЕКСТ ДЛЯ ПОИСКА
  //  Проблема: «Бабочка», «Планка», «Мост», «Лодка», «Скручивание»,
  //  «Наклон вперёд» — пересекаются с упражнениями из зала.
  //  Решение: контекст + санскритское название для проблемных поз.
  // ═══════════════════════════════════════════════════════════

  /// Базовый контекст в зависимости от категории.
  String get _baseContext {
    return _isYoga ? 'йога поза' : 'растяжка stretching';
  }

  /// Спец-контекст для известных проблемных названий.
  /// Ключ — точное имя из БД, значение — что добавить в запрос.
  String? get _specialContext {
    final name = stretch.name.toLowerCase();

    // 🔴 Критичные коллизии с тренажёрами/упражнениями из зала
    if (name == 'бабочка' || name == 'поза бабочки' || name == 'поза бабочки лёжа') {
      return 'баддха конасана йога';
    }
    if (name == 'планка йога') {
      return 'йога планка кумбхакасана';
    }
    if (name == 'боковая планка йога') {
      return 'йога боковая планка васиштхасана';
    }
    if (name == 'поза моста') {
      return 'йога мост сету бандха сарвангасана';
    }
    if (name == 'поза лодки') {
      return 'йога лодка навасана';
    }
    if (name == 'скручивание лёжа' || name == 'скручивание сидя') {
      return 'йога скручивание позвоночника';
    }
    if (name == 'поза героя') {
      return 'йога вирасана';
    }
    if (name == 'поза дерева') {
      return 'йога врикшасана';
    }
    if (name == 'наклон вперёд сидя' || name == 'наклон к прямым ногам стоя' || name == 'наклон вперёд стоя') {
      return _isYoga ? 'йога пашчимоттанасана' : 'растяжка задней поверхности бедра';
    }
    if (name == 'поза кобры') {
      return 'йога бхуджангасана';
    }
    if (name == 'поза сфинкса') {
      return 'йога сфинкс';
    }
    if (name == 'поза голубя') {
      return 'йога капотасана';
    }
    if (name == 'поза ящерицы') {
      return 'йога уттхана пришватханасана';
    }
    if (name == 'поза лягушки' || name == 'растяжка лягушки') {
      return 'йога мандукасана';
    }
    if (name == 'поза верблюда') {
      return 'йога уштрасана';
    }
    if (name == 'поза воина i' || name == 'поза воина ii') {
      return 'йога вирабхадрасана';
    }
    if (name == 'поза горы') {
      return 'йога тадасана';
    }
    if (name == 'поза трупа') {
      return 'йога шавасана';
    }
    if (name == 'поза ребёнка') {
      return 'йога баласана';
    }
    if (name == 'собака мордой вниз') {
      return 'йога адхо мукха шванасана';
    }
    if (name == 'поза вытянутого угла') {
      return 'йога упавиштха конасана';
    }
    if (name == 'поза счастливого ребёнка') {
      return 'йога ананда баласана';
    }
    if (name == 'ноги вверх на стене') {
      return 'йога випарита карани';
    }

    return null;
  }

  /// Итоговый префикс для запроса.
  String get _searchPrefix {
    final special = _specialContext;
    if (special != null) return special;
    return _baseContext;
  }

  /// Полный поисковый запрос: «контекст + название + действие».
  String _buildQuery(String action) {
    return '$_searchPrefix ${stretch.name} $action';
  }

  // ═══════════════════════════════════════════════════════════
  //  ОТКРЫТИЕ ЯНДЕКС-ССЫЛОК
  // ═══════════════════════════════════════════════════════════

  Future<void> _openYandexVideo(BuildContext context) async {
    final query = Uri.encodeComponent(_buildQuery('техника выполнения'));
    final url = Uri.parse(
      'https://yandex.ru/video/search?text=$query',
    );
    await _launch(context, url);
  }

  Future<void> _openYandexImages(BuildContext context) async {
    final query = Uri.encodeComponent(_buildQuery('техника выполнения'));
    final url = Uri.parse(
      'https://yandex.ru/images/search?text=$query',
    );
    await _launch(context, url);
  }

  Future<void> _openYandexAnatomy(BuildContext context) async {
    final query = Uri.encodeComponent(_buildQuery('анатомия мышц'));
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
          stretch.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(theme),
          const SizedBox(height: 16),
          _buildBadges(theme),
          const SizedBox(height: 20),

          _buildSearchButtons(context, theme),
          const SizedBox(height: 24),

          if (stretch.description.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.article_rounded,
              title: 'Описание',
              color: const Color(0xFF6C5CE7),
              child: Text(
                stretch.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),

          if (stretch.technique.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.rule_rounded,
              title: 'Техника выполнения',
              color: const Color(0xFF00B894),
              child: Text(
                stretch.technique,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),

          if (stretch.benefits.trim().isNotEmpty)
            _section(
              theme,
              icon: Icons.favorite_rounded,
              title: 'Польза',
              color: const Color(0xFFE17055),
              child: Text(
                stretch.benefits,
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
        _badge(
          theme,
          icon: Icons.category_rounded,
          label: stretch.categoryLabel,
          color: _isYoga
              ? const Color(0xFF6C5CE7)
              : const Color(0xFF00B894),
        ),
        _badge(
          theme,
          icon: Icons.fitness_center,
          label: _muscleLabel(stretch.muscleGroup),
          color: const Color(0xFF6C5CE7),
        ),
        _badge(
          theme,
          icon: Icons.timer_rounded,
          label: stretch.durationLabel,
          color: const Color(0xFFE17055),
        ),
        if (stretch.bothSides)
          _badge(
            theme,
            icon: Icons.compare_arrows_rounded,
            label: 'Обе стороны',
            color: const Color(0xFFFDCB6E),
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
      'hips': 'бёдра',
      'adductors': 'внутренняя поверхность',
      'neck': 'шея',
      'forearms': 'предплечья',
      'full_body': 'всё тело',
      'breathing': 'дыхание',
    };
    return map[code] ?? code;
  }
}
// ═══ ФАЙЛ stretch_detail_screen.dart ЗАВЕРШЁН ═══