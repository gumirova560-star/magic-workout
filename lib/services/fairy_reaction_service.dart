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

  /// Колбэк — показать сообщение феи.
  void Function(String message, FairyMood mood)? onEvent;

  /// Колбэк — активный профиль изменился.
  /// Вызывается из setActiveProfile, если id или name поменялись.
  void Function()? onProfileChanged;

  String? _profileName;
  String? _profileGender;
  int? _activeProfileId;
  FairyMood _currentMood = FairyMood.happy;

  String? get profileName => _profileName;
  String? get profileGender => _profileGender;
  int? get activeProfileId => _activeProfileId;
  FairyMood get currentMood => _currentMood;

  // ═══ Активный профиль ═══

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

    // ═══ Сообщаем подписчикам (фее), что профиль сменился ═══
    if (changed) {
      onProfileChanged?.call();
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

  // ═══ Эмоция ═══

  void setMood(FairyMood mood) {
    _currentMood = mood;
  }

  // ═══ События ═══

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

    if (message.isEmpty) return;

    final usedMood = mood ?? FairyPhrases.eventMood(eventKey);
    _currentMood = usedMood;

    if (eventKey == 'workout_completed') {
      await FairyStatsService.recordWorkout();
    }

    onEvent?.call(message, usedMood);
  }

  void say(String message, {FairyMood? mood}) {
    final usedMood = mood ?? FairyMood.happy;
    _currentMood = usedMood;
    final m = FairyPhrases.apply(
      message,
      _profileName,
      gender: _profileGender,
    );
    onEvent?.call(m, usedMood);
  }
}