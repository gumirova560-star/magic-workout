import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/fairy_mood.dart';
import '../data/fairy_phrases.dart';
import '../services/database_helper.dart';
import '../services/fairy_reaction_service.dart';
import '../services/fairy_stats_service.dart';

/// Плавающая фея — 12×12, появляется СВЕРХУ, позиции по экранам.
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

    // ⚠️ Подписываемся как слушатель событий (список, не одиночный onEvent)
    FairyReactionService().addEventListener(_onFairyEvent);

    FairyReactionService().addProfileListener(_onProfileChanged);

    _initPhrases().then((_) async {
      if (!mounted) return;

      for (final mood in FairyMood.values) {
        try {
          await precacheImage(AssetImage(mood.asset), context);
        } catch (_) {}
      }

      if (!mounted) return;

      if (_phrases.isNotEmpty) {
        _show();
      }
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

  // ⚠️ Событие от сервиса — подменяем фразу и показываем
  void _onFairyEvent(String message, FairyMood mood) {
    debugPrint('🧚 FairyBubble.onEvent: "$message", mounted=$mounted');
    if (!mounted) return;
    setState(() {
      _phrases = [(text: message, mood: mood)];
      _phraseIndex = 0;
    });
    _show();
  }

  void _onProfileChanged() {
    if (!mounted) return;

    // ⚠️ Если сервис держит фразу (profile_changed_ask) — не трогаем
    if (FairyReactionService().isHoldingScreenPhrases) {
      debugPrint('🧚 _onProfileChanged skipped (hold)');
      return;
    }

    _initPhrases().then((_) {
      if (mounted) {
        setState(() => _phraseIndex = 0);
        _show();
      }
    });
  }

  Future<void> _initPhrases() async {
    // ⚠️ Если сервис держит фразы — не загружаем byScreen,
    //    чтобы не перебить событийную фразу (profile_changed_ask)
    if (FairyReactionService().isHoldingScreenPhrases) {
      debugPrint('🧚 _initPhrases SKIPPED (hold)');
      return;
    }

    try {
      await FairyReactionService().loadActiveProfile();

      var name = FairyReactionService().profileName;
      var gender = FairyReactionService().profileGender;
      var id = FairyReactionService().activeProfileId;

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

      String? goal;
      if (id != null) {
        final profile = await DatabaseHelper.instance.getProfileById(id);
        goal = profile?.goal;
      }

      final hour = DateTime.now().hour;
      final streak = await FairyStatsService.getStreak();
      final daysSince = await FairyStatsService.daysSinceLastWorkout();

      if (name == null || name.trim().isEmpty) {
        _phrases = FairyPhrases.forSituationWithMood(
          'no_profile',
          name: null,
          gender: gender,
        );
      } else if (daysSince >= 2 && daysSince < 100) {
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
      } else {
        final templates = id != null
            ? await DatabaseHelper.instance.getAutoTemplates(id)
            : <dynamic>[];

        if (id != null && templates.isEmpty) {
          if (widget.screenKey == 'workout') {
            _phrases = FairyPhrases.forSituationWithMood(
              'no_plan',
              name: name,
              gender: gender,
            );
          } else {
            _phrases = FairyPhrases.forScreenWithMood(
              widget.screenKey,
              name: name,
              gender: gender,
            );
          }
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
          _phrases = [
            ...screenPhrases,
            (text: contextText, mood: contextMood),
          ];
        }
      }

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

    FairyReactionService().removeEventListener(_onFairyEvent);
    FairyReactionService().removeProfileListener(_onProfileChanged);

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
    _hideTimer = Timer(const Duration(seconds: 4), () {
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
  //  ПОЗИЦИИ ПО ЭКРАНАМ
  // ═══════════════════════════════════════════════════════════

  double _topForScreen() {
    switch (widget.screenKey) {
      case 'profiles':
        return 70;
      case 'workout':
        return 60;
      case 'workout_detail':
        return 60;
      case 'yoga':
        return 70;
      case 'progress':
        return 70;
      case 'history':
        return 70;
      case 'settings':
        return 70;
      default:
        return 70;
    }
  }

  double _rightForScreen() {
    switch (widget.screenKey) {
      case 'workout':
        return 16;
      case 'workout_detail':
        return 16;
      case 'settings':
        return 16;
      default:
        return 16;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  СВЕЧЕНИЕ
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

    final glowIntensity = mood == FairyMood.party ? 0.30 : 0.22;
    final glowSize = mood == FairyMood.party ? 55.0 : 45.0;
    final glowAmplitude = mood == FairyMood.party ? 0.08 : 0.06;

    return AnimatedBuilder(
      animation: Listenable.merge([_wingController, _sparkController]),
      builder: (context, child) {
        final t = _wingController.value;
        final angle = 2 * math.pi * t;
        final scale = 1.0 + 0.008 * math.sin(angle * 2);

        final glowT = _sparkController.value;
        final glowOpacity =
            glowIntensity + glowAmplitude * math.sin(glowT * 2 * math.pi);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
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
            Transform.scale(
              scale: scale,
              child: child,
            ),
            if (showSparks) ...[
              _sparkAbove(glowT, 0.00, -55, -8, const Color(0xFFFFD166)),
              _sparkAbove(glowT, 0.20, -62, 6, const Color(0xFFEF476F)),
              _sparkAbove(glowT, 0.40, -48, -4, const Color(0xFF06D6A0)),
              _sparkAbove(glowT, 0.60, -58, 8, const Color(0xFF118AB2)),
              _sparkAbove(glowT, 0.80, -52, -6, const Color(0xFF9B5DE5)),
            ],
          ],
        );
      },
      child: Image.asset(
        mood.asset,
        key: ValueKey(mood),
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded || frame != null) return child;
          return const SizedBox.shrink();
        },
        errorBuilder: (_, __, ___) => const Icon(
          Icons.auto_awesome,
          size: 12,
        ),
      ),
    );
  }

  Widget _sparkAbove(
    double t,
    double phase,
    double baseY,
    double xOffset,
    Color color,
  ) {
    final a = 2 * math.pi * (t + phase);

    final driftY = 6 * math.sin(a * 2);
    final driftX = 3 * math.cos(a * 3);

    final opacity = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(a * 4));

    return Transform.translate(
      offset: Offset(xOffset + driftX, baseY + driftY),
      child: Container(
        width: 3.5,
        height: 3.5,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.7),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Size _measureBubbleSize(String text, TextStyle style) {
    const maxWidth = 240.0;
    const minWidth = 120.0;

    const padLeft = 24.0;
    const padRight = 36.0;
    const padTop = 14.0;
    const padBottom = 24.0;

    const tailExtraRight = 45.0;
    const tailExtraBottom = 15.0;

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth - padLeft - padRight);

    final textW = tp.width;
    final textH = tp.height;

    final bubbleW = (textW + padLeft + padRight).clamp(minWidth, maxWidth);
    final bubbleH = (textH + padTop + padBottom).clamp(50.0, 130.0);

    return Size(
      bubbleW + tailExtraRight,
      bubbleH + tailExtraBottom,
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

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: theme.colorScheme.onSurface,
        ) ??
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    final bubbleSize = _measureBubbleSize(item.text, textStyle);

    return Positioned(
      top: _topForScreen(),
      right: _rightForScreen(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isDisappearing =
              _controller.status == AnimationStatus.reverse;
          final offset =
              isDisappearing ? _slideUpOut.value : _slideFromTop.value;

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: SizedBox(
                  width: bubbleSize.width,
                  height: bubbleSize.height,
                  child: CustomPaint(
                    painter: _SpeechBubblePainter(
                      fillColor: theme.colorScheme.surface,
                      borderColor: Colors.black.withOpacity(0.25),
                      shadowColor: Colors.black.withOpacity(0.15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 22,
                        right: 34,
                        top: 16,
                        bottom: 26,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.text,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _hide,
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: 140,
                    minHeight: 0,
                    maxHeight: 180,
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildLiveFairy(item.mood),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  РИСУЕТ ПУЗЫРЬ (ОВАЛ) + ХВОСТИК («КАПЕЛЬКА»)
// ═══════════════════════════════════════════════════════════

class _SpeechBubblePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;

  _SpeechBubblePainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bubbleWidth = size.width - 25;
    final bubbleHeight = size.height - 20;

    final bubbleRect = Rect.fromLTWH(
      0,
      0,
      bubbleWidth,
      bubbleHeight,
    );

    final ovalPath = Path()..addOval(bubbleRect);

    final tailPath = Path();

    final tailBaseTop = Offset(
      bubbleWidth - 20,
      bubbleHeight * 0.55,
    );
    final tailBaseBottom = Offset(
      bubbleWidth - 15,
      bubbleHeight * 0.95,
    );

    final tailTip = Offset(
      bubbleWidth + 30,
      bubbleHeight * 0.95,
    );

    tailPath.moveTo(tailBaseTop.dx, tailBaseTop.dy);
    tailPath.cubicTo(
      bubbleWidth + 5, bubbleHeight * 0.55,
      bubbleWidth + 15, bubbleHeight * 0.7,
      tailTip.dx, tailTip.dy,
    );
    tailPath.cubicTo(
      bubbleWidth + 15, bubbleHeight * 0.85,
      bubbleWidth + 5, bubbleHeight * 0.9,
      tailBaseBottom.dx, tailBaseBottom.dy,
    );
    tailPath.close();

    final combined = Path.combine(
      PathOperation.union,
      ovalPath,
      tailPath,
    );

    canvas.drawShadow(combined, shadowColor, 6, false);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(combined, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    canvas.drawPath(combined, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}