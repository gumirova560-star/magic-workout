import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/fairy_mood.dart';
import '../data/fairy_phrases.dart';
import '../services/database_helper.dart';
import '../services/fairy_reaction_service.dart';
import '../services/fairy_stats_service.dart';

/// Плавающая фея — появляется СВЕРХУ ПО ЦЕНТРУ.
///
/// Этап D:
/// - 🦋 Полёт сверху вниз
/// - ✨ Взлёт вверх при исчезновении
/// - 💫 Искры высоко над головой при mood.party (салют)
/// - 🌟 Свечение мягкое, едва заметное, своего цвета для каждой эмоции
///
/// Размер: фея 44×44, свечение 110/130 (мягкое), искры 70–110.
class FairyBubble extends StatefulWidget {
  final String screenKey;

  const FairyBubble({super.key, required this.screenKey});

  @override
  State<FairyBubble> createState() => _FairyBubbleState();
}

class _FairyBubbleState extends State<FairyBubble>
    with TickerProviderStateMixin {
  List<({String text, FairyMood mood})> _phrases = [];
  int _phraseIndex = 0;
  bool _visible = false;
  Timer? _hideTimer;

  late AnimationController _controller;
  late Animation<Offset> _slideFromTop;
  late Animation<Offset> _slideUpOut;
  late Animation<double> _fadeAnimation;

  late AnimationController _wingController;
  late AnimationController _sparkController;

  @override
  void initState() {
    super.initState();

    // ═══ Подписка на события феи ═══
    FairyReactionService().onEvent = (message, mood) {
      if (!mounted) return;
      setState(() {
        _phrases = [(text: message, mood: mood)];
        _phraseIndex = 0;
      });
      _show();
    };

    // ═══ Подписка: профиль изменился ═══
    FairyReactionService().onProfileChanged = () {
      if (!mounted) return;
      _initPhrases().then((_) {
        if (mounted) {
          setState(() => _phraseIndex = 0);
          _show();
        }
      });
    };

    // ═══ _show() ПОСЛЕ _initPhrases() ═══
    _initPhrases().then((_) {
      if (!mounted) return;
      _show();
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideFromTop = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _slideUpOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _wingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  Future<void> _initPhrases() async {
    try {
      await FairyReactionService().loadActiveProfile();

      var name = FairyReactionService().profileName;
      var gender = FairyReactionService().profileGender;
      var id = FairyReactionService().activeProfileId;

      // ═══ RETRY ═══
      if (name == null || name.trim().isEmpty) {
        for (int attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(const Duration(milliseconds: 300));
          final profiles = await DatabaseHelper.instance.getProfiles();
          if (profiles.isNotEmpty) {
            final first = profiles.first;
            await FairyReactionService().setActiveProfile(
              first.id,
              first.name,
              gender: first.gender,
            );
            name = first.name;
            gender = first.gender;
            id = first.id;
            break;
          }
        }
      }

      // ═══ Goal ═══
      String? goal;
      if (id != null) {
        final profile = await DatabaseHelper.instance.getProfileById(id);
        goal = profile?.goal;
      }

      final hour = DateTime.now().hour;
      final streak = await FairyStatsService.getStreak();
      final daysSince = await FairyStatsService.daysSinceLastWorkout();

      // ═══ ВЕТКА 4: Профиля нет ═══
      if (name == null || name.trim().isEmpty) {
        _phrases = FairyPhrases.forSituationWithMood(
          'no_profile',
          name: null,
          gender: gender,
        );
      }
      // ═══ ВЕТКА 5: Comeback ═══
      else if (daysSince >= 2 && daysSince < 100) {
        _phrases = [
          ...FairyPhrases.forScreenWithMood('default',
              name: name, gender: gender),
          ...FairyPhrases.comeback
              .map((t) => (
                    text: FairyPhrases.apply(t, name, gender: gender),
                    mood: FairyMood.sleepy,
                  ))
              .toList(),
        ];
      }
      // ═══ ВЕТКА 6 и 7 ═══
      else {
        final templates = id != null
            ? await DatabaseHelper.instance.getTemplates(id)
            : <dynamic>[];

        if (id != null && templates.isEmpty) {
          _phrases = FairyPhrases.forSituationWithMood(
            'no_plan',
            name: name,
            gender: gender,
          );
        } else {
          final screenPhrases = FairyPhrases.forScreenWithMood(
            widget.screenKey,
            name: name,
            gender: gender,
          );
          final contextText = FairyPhrases.contextualPhrase(
            hour: hour,
            name: name,
            streakDays: streak,
            gender: gender,
          );
          final contextMood = FairyPhrases.contextualMood(
            hour: hour,
            streakDays: streak,
          );
          final goalText = FairyPhrases.contextualPhrase(
            hour: hour,
            name: name,
            goal: goal,
            gender: gender,
          );
          _phrases = [
            ...screenPhrases,
            (text: contextText, mood: contextMood),
            (text: goalText, mood: FairyMood.wink),
          ];
        }
      }

      // ═══ FALLBACK ═══
      if (_phrases.isEmpty) {
        _phrases = [
          (
            text: 'Привет, ${name ?? "друг"}! Я твоя фея 🧚',
            mood: FairyMood.happy,
          ),
        ];
      }
    } catch (e, stack) {
      debugPrint('❌ ОШИБКА в _initPhrases: $e');
      debugPrint('$stack');
      _phrases = [
        (text: 'Привет! Я твоя фея 🧚', mood: FairyMood.happy),
      ];
    }
  }

  @override
  void didUpdateWidget(covariant FairyBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenKey != widget.screenKey) {
      _initPhrases().then((_) {
        if (mounted) {
          setState(() => _phraseIndex = 0);
          _show();
        }
      });
    }
  }

  Future<void> refresh() async {
    await _initPhrases();
    if (mounted) {
      setState(() => _phraseIndex = 0);
      _show();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _wingController.dispose();
    _sparkController.dispose();
    if (FairyReactionService().onProfileChanged != null) {
      FairyReactionService().onProfileChanged = null;
    }
    super.dispose();
  }

  void _show() {
    if (_phrases.isEmpty) return;
    if (!mounted) return;
    setState(() => _visible = true);
    _controller.forward(from: 0);
    _scheduleHide();
  }

  void _hide() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) _hide();
    });
  }

  void _nextPhrase() {
    if (_phrases.isEmpty) return;
    setState(() {
      _phraseIndex = (_phraseIndex + 1) % _phrases.length;
    });
    _scheduleHide();
  }

  // ═══════════════════════════════════════════════════════════
  //  ЦВЕТ СВЕЧЕНИЯ ДЛЯ КАЖДОЙ ЭМОЦИИ
  // ═══════════════════════════════════════════════════════════
  Color _glowColor(FairyMood mood) {
    switch (mood) {
      case FairyMood.happy:
        return const Color(0xFFFFB800);
      case FairyMood.wink:
        return const Color(0xFF7C5CFF);
      case FairyMood.think:
        return const Color(0xFF3E7BFA);
      case FairyMood.party:
        return const Color(0xFF9B30FF);
      case FairyMood.sleepy:
        return const Color(0xFF9D8EC4);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ЖИВАЯ ФЕЯ
  // ═══════════════════════════════════════════════════════════
  Widget _buildLiveFairy(FairyMood mood) {
    final showSparks = mood == FairyMood.party;
    final glowColor = _glowColor(mood);

    // ═══ Мягкое свечение, едва заметное ═══
    final glowIntensity = mood == FairyMood.party ? 0.30 : 0.22;
    final glowSize = mood == FairyMood.party ? 130.0 : 110.0;
    final glowAmplitude = mood == FairyMood.party ? 0.08 : 0.06;

    return AnimatedBuilder(
      animation: Listenable.merge([_wingController, _sparkController]),
      builder: (context, child) {
        final t = _wingController.value;
        final angle = 2 * math.pi * t;
        final scale = 1.0 + 0.008 * math.sin(angle * 2);

        final glowT = _sparkController.value;
        final glowOpacity = glowIntensity +
            glowAmplitude * math.sin(glowT * 2 * math.pi);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ═══ Свечение — мягкое, едва заметное ═══
            Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(glowOpacity * 0.5),
                    glowColor.withOpacity(glowOpacity),
                    glowColor.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // ═══ Фея ═══
            Transform.scale(
              scale: scale,
              child: child,
            ),

            // ═══ Искры — высоко над головой ═══
            if (showSparks) ...[
              _spark(glowT, 0.0, 70, const Color(0xFFFFD166)),
              _spark(glowT, 0.15, 85, const Color(0xFFEF476F)),
              _spark(glowT, 0.3, 100, const Color(0xFF06D6A0)),
              _spark(glowT, 0.45, 110, const Color(0xFF118AB2)),
              _spark(glowT, 0.6, 75, const Color(0xFF9B5DE5)),
              _spark(glowT, 0.75, 95, const Color(0xFFF15BB5)),
            ],
          ],
        );
      },
      child: Image.asset(
        mood.asset,
        key: ValueKey(mood),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.auto_awesome,
          size: 26,
        ),
      ),
    );
  }

  /// Искра — вылетает высоко ВВЕРХ за голову феи (салют).
  Widget _spark(double t, double phase, double radius, Color color) {
    final a = 2 * math.pi * (t + phase);

    final x = 20 * math.cos(a);
    final y = -radius - 12 * math.sin(a);

    final opacity = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(a * 3));

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.7),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _phrases.isNotEmpty ? _phrases[_phraseIndex] : null;

    if (!_visible || item == null || item.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 130,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isDisappearing =
              _controller.status == AnimationStatus.reverse;
          final offset = isDisappearing
              ? _slideUpOut.value
              : _slideFromTop.value;

          return FractionalTranslation(
            translation: offset,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: _nextPhrase,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══ Фея 44×44 (ещё меньше) ═══
              SizedBox(
                width: 44,
                height: 44,
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: 280,
                  minHeight: 0,
                  maxHeight: 420,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildLiveFairy(item.mood),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ═══ Облачко ═══
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        item.text,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _hide,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}