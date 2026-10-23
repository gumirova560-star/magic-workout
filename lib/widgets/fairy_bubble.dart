import 'dart:async';
import 'package:flutter/material.dart';
import '../data/fairy_mood.dart';
import '../data/fairy_phrases.dart';
import '../services/fairy_reaction_service.dart';
import '../services/database_helper.dart';

class FairyBubble extends StatefulWidget {
  final String screenKey;

  const FairyBubble({super.key, required this.screenKey});

  @override
  State<FairyBubble> createState() => _FairyBubbleState();
}

class _FairyBubbleState extends State<FairyBubble> {
  String _text = '';
  FairyMood _mood = FairyMood.happy;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initFairy();
    FairyReactionService().addEventListener(_onFairyEvent);
  }

  @override
  void didUpdateWidget(covariant FairyBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenKey != widget.screenKey) {
      _hideTimer?.cancel();
      setState(() { _visible = false; _text = ''; });
      _initFairy();
    }
  }

  Future<void> _initFairy() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    String name = 'друг';
    String? gender;
    int? profileId;

    try {
      await FairyReactionService().loadActiveProfile();
      name = FairyReactionService().profileName ?? 'друг';
      gender = FairyReactionService().profileGender;
      profileId = FairyReactionService().activeProfileId;
    } catch (_) {}

    // ⚠️ ПРОВЕРКА: Есть ли уже план на экране тренировок
    if (widget.screenKey == 'workout' && profileId != null) {
      final allDays = await DatabaseHelper.instance.getWorkoutDays(
        profileId: profileId,
        limit: 100,
      );
      final hasMonthPlan = allDays.any((d) => d.weekNumber != null);

      if (!hasMonthPlan) {
        _show('Профиль готов, $name! 🎉 Составим план?', FairyMood.think);
        return;
      }
    }

    final phrases = FairyPhrases.forScreenWithMood(
      widget.screenKey, name: name, gender: gender,
    );

    if (phrases.isNotEmpty) {
      final randomIndex = DateTime.now().millisecondsSinceEpoch % phrases.length;
      final selected = phrases[randomIndex];
      _show(selected.text, selected.mood);
    }
  }

  void _show(String text, FairyMood mood) {
    if (!mounted) return;
    setState(() { _text = text; _mood = mood; _visible = true; });
    _scheduleHide();
  }

  void _onFairyEvent(String message, FairyMood mood) {
    if (!mounted) return;
    _show(message, mood);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    FairyReactionService().removeEventListener(_onFairyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isYoga = widget.screenKey == 'yoga' || _mood == FairyMood.yoga;

    return Positioned(
      top: isYoga ? null : 100,
      bottom: isYoga ? 250 : null,
      right: 20,
      child: GestureDetector(
        onTap: () => setState(() => _visible = false),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Text(_text, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Image.asset(
              _mood.asset, width: 80, height: 80, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 40, color: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }
}