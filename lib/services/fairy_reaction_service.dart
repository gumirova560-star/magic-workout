import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fairy_mood.dart';
import '../data/fairy_phrases.dart';
import '../services/fairy_stats_service.dart';
import '../services/database_helper.dart';

/// Глобальный сервис событий для феи + активный профиль + род + эмоция.
class FairyReactionService {
  static final FairyReactionService _instance =
      FairyReactionService._internal();
  factory FairyReactionService() => _instance;
  FairyReactionService._internal();

  static const _keyActiveProfile = 'active_profile_id';

  // ═══════════════════════════════════════════════════════════
  //  СЛУШАТЕЛИ СОБЫТИЙ ФЕИ (замена одиночного onEvent)
  // ═══════════════════════════════════════════════════════════
  //
  // ⚠️ Раньше был один `onEvent` — при пересоздании FairyBubble он
  //    терялся (оставался замкнутым на disposed state). Теперь —
  //    список подписчиков, каждый добавляется в initState и
  //    удаляется в dispose.

  final List<void Function(String message, FairyMood mood)> _eventListeners = [];

  void addEventListener(void Function(String, FairyMood) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  void removeEventListener(void Function(String, FairyMood) listener) {
    _eventListeners.remove(listener);
  }

  /// ⚠️ Оставлено для совместимости со старым кодом — оборачивает
  ///    колбэк в список. Не использовать в новом коде.
  @Deprecated('Используйте addEventListener/removeEventListener')
  set onEvent(void Function(String, FairyMood)? listener) {
    _eventListeners.clear();
    if (listener != null) _eventListeners.add(listener);
  }

  void _emit(String message, FairyMood mood) {
    for (final l in List.of(_eventListeners)) {
      try {
        l(message, mood);
      } catch (e) {
        debugPrint('❌ eventListener error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  СЛУШАТЕЛИ СМЕНЫ ПРОФИЛЯ
  // ═══════════════════════════════════════════════════════════

  final List<VoidCallback> _profileListeners = [];

  void addProfileListener(VoidCallback listener) {
    if (!_profileListeners.contains(listener)) {
      _profileListeners.add(listener);
    }
  }

  void removeProfileListener(VoidCallback listener) {
    _profileListeners.remove(listener);
  }

  void notifyProfileChanged() {
    for (final l in List<VoidCallback>.from(_profileListeners)) {
      try {
        l();
      } catch (e) {
        debugPrint('❌ profileListener error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  СЛУШАТЕЛИ ЗАВЕРШЕНИЯ ТРЕНИРОВКИ
  // ═══════════════════════════════════════════════════════════

  final List<VoidCallback> _workoutListeners = [];

  void addWorkoutListener(VoidCallback listener) {
    if (!_workoutListeners.contains(listener)) {
      _workoutListeners.add(listener);
    }
  }

  void removeWorkoutListener(VoidCallback listener) {
    _workoutListeners.remove(listener);
  }

  void notifyWorkoutCompleted() {
    for (final l in List<VoidCallback>.from(_workoutListeners)) {
      try {
        l();
      } catch (e) {
        debugPrint('❌ workoutListener error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  АКТИВНЫЙ ПРОФИЛЬ
  // ═══════════════════════════════════════════════════════════

  String? _profileName;
  String? _profileGender;
  int? _activeProfileId;
  FairyMood _currentMood = FairyMood.happy;

  String? get profileName => _profileName;
  String? get profileGender => _profileGender;
  int? get activeProfileId => _activeProfileId;
  FairyMood get currentMood => _currentMood;

  Future<void> setActiveProfile(
    int? id,
    String? name, {
    String? gender,
  }) async {
    final changed = id != _activeProfileId || name != _profileName;

    _activeProfileId = id;
    _profileName = name;
    _profileGender = gender;

    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_keyActiveProfile);
    } else {
      await prefs.setInt(_keyActiveProfile, id);
    }

    if (changed) {
      notifyProfileChanged();
    }
  }

  Future<void> loadActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_keyActiveProfile);

    if (id != null) {
      final profile = await DatabaseHelper.instance.getProfileById(id);
      if (profile != null) {
        _activeProfileId = id;
        _profileName = profile.name;
        _profileGender = profile.gender;
        return;
      }
    }

    final profiles = await DatabaseHelper.instance.getProfiles();
    if (profiles.isNotEmpty) {
      _activeProfileId = profiles.first.id;
      _profileName = profiles.first.name;
      _profileGender = profiles.first.gender;
      await prefs.setInt(_keyActiveProfile, profiles.first.id!);
    } else {
      _activeProfileId = null;
      _profileName = null;
      _profileGender = null;
    }
  }

  void setName(String? name) => _profileName = name;

  void setGender(String? gender) => _profileGender = gender;

  Future<void> refreshName() async {
    await loadActiveProfile();
  }

  // ═══════════════════════════════════════════════════════════
  //  ЭМОЦИЯ
  // ═══════════════════════════════════════════════════════════

  void setMood(FairyMood mood) {
    _currentMood = mood;
  }

  // ═══════════════════════════════════════════════════════════
  //  HOLD SCREEN PHRASES
  // ═══════════════════════════════════════════════════════════

  bool _holdScreenPhrases = false;

  bool get isHoldingScreenPhrases => _holdScreenPhrases;

  void holdScreenPhrases() {
    _holdScreenPhrases = true;
  }

  void releaseScreenPhrases() {
    _holdScreenPhrases = false;
  }

  // ═══════════════════════════════════════════════════════════
  //  СОБЫТИЯ
  // ═══════════════════════════════════════════════════════════

  Future<void> trigger(
    String eventKey, {
    String? customMessage,
    String? nameOverride,
    FairyMood? mood,
  }) async {
    final name = nameOverride ?? _profileName;
    final gender = _profileGender;

    String message;
    if (customMessage != null) {
      message = FairyPhrases.apply(customMessage, name, gender: gender);
    } else {
      message = FairyPhrases.eventPhrase(
        eventKey,
        name: name,
        gender: gender,
      );
    }

    debugPrint('🧚 trigger: key=$eventKey, isEmpty=${message.isEmpty}, '
        'listeners=${_eventListeners.length}');

    if (message.isEmpty) return;

    final usedMood = mood ?? FairyPhrases.eventMood(eventKey);
    _currentMood = usedMood;

    if (eventKey == 'workout_completed') {
      await FairyStatsService.recordWorkout();
      notifyWorkoutCompleted();
    }

    _emit(message, usedMood);
  }

  Future<void> saySituation(String situationKey) async {
    final phrases = FairyPhrases.forSituationWithMood(
      situationKey,
      name: _profileName,
      gender: _profileGender,
    );

    if (phrases.isEmpty) return;

    final pick = phrases[
      DateTime.now().millisecondsSinceEpoch % phrases.length
    ];

    _currentMood = pick.mood;
    _emit(pick.text, pick.mood);
  }

  void say(String message, {FairyMood? mood}) {
    final usedMood = mood ?? FairyMood.happy;
    _currentMood = usedMood;
    final m = FairyPhrases.apply(
      message,
      _profileName,
      gender: _profileGender,
    );
    _emit(m, usedMood);
  }
}