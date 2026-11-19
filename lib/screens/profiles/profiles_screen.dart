import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'profile_edit_screen.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  UserProfile? _profile;
  bool _loading = true;
  final ImagePicker _picker = ImagePicker();

  static const String _activeProfileIdKey = 'active_profile_id';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ═══ АКТИВНЫЙ ПРОФИЛЬ ═══
  // Храним id активного профиля в SharedPreferences: логика «profiles.first»
  // хрупкая — при смене сортировки активным станет другой человек.
  Future<UserProfile?> _resolveActiveProfile(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_activeProfileIdKey);

    if (savedId != null) {
      final byId = profiles.where((pr) => pr.id == savedId).toList();
      if (byId.isNotEmpty) return byId.first;
    }
    // Fallback: старое поведение — первый по createdAt; запоминаем его
    await prefs.setInt(_activeProfileIdKey, profiles.first.id!);
    return profiles.first;
  }

  // ═══ ХЕШ ПРОФИЛЯ ═══
  // Тот же набор полей, что и в WorkoutScreen._computeProfileHash,
  // включая trainingWeekdays: сравниваем до/после редактирования,
  // чтобы триггерить «профиль изменён» только при реальной смене данных.
  String _computeProfileHash(UserProfile pr) {
    return [
      pr.gender, pr.age, pr.height, pr.weight, pr.level, pr.goal,
      pr.equipment, pr.daysPerWeek, pr.sessionMinutes,
      pr.trainingWeekdays.join(','),
      pr.focusAreas.join(','), pr.limitations.join(','),
    ].join('|');
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    List<UserProfile> profiles;
    try {
      profiles = await DatabaseHelper.instance.getProfiles();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки профиля: $e'),
          action: SnackBarAction(label: 'Повторить', onPressed: _loadProfile),
        ),
      );
      return;
    }

    if (profiles.isEmpty) {
      for (int attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          profiles = await DatabaseHelper.instance.getProfiles();
        } catch (_) {}
        if (profiles.isNotEmpty) break;
      }
    }

    if (!mounted) return;

    if (profiles.isEmpty) {
      setState(() {
        _profile = null;
        _loading = false;
      });
      await FairyReactionService().setActiveProfile(null, null);
      return;
    }

    final active = await _resolveActiveProfile(profiles);
    if (active == null) {
      setState(() {
        _profile = null;
        _loading = false;
      });
      return;
    }

    await FairyReactionService().setActiveProfile(
      active.id,
      active.name,
      gender: active.gender,
    );

    setState(() {
      _profile = active;
      _loading = false;
    });
  }

  // ═══ АВАТАР ═══
  // 👇 ИЗМЕНЕНО: фото сохраняется в файл, в БД — только путь.
  // Base64-аватары старых профилей остаются читаемыми (обратная совместимость).
  bool _isFilePath(String? value) => value != null && value.startsWith('/');

  ImageProvider? _avatarImageProvider(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (_isFilePath(avatarPath)) {
      final file = File(avatarPath);
      if (file.existsSync()) return FileImage(file);
      return null; // файл удалён — покажем заглушку с инициалом
    }
    // Легаси: старый base64
    try {
      return MemoryImage(base64Decode(avatarPath));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    if (_profile == null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return; // 👇 пользователь мог уйти с экрана во время чтения

    String newPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory(p.join(dir.path, 'avatars'));
      if (!avatarsDir.existsSync()) avatarsDir.createSync(recursive: true);
      newPath = p.join(avatarsDir.path, 'avatar_${_profile!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(newPath).writeAsBytes(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить фото: $e')));
      }
      return;
    }

    // Удаляем старый файл-аватар, если он был (base64-легаси не трогаем)
    final oldPath = _profile!.avatarPath;
    if (oldPath != null && _isFilePath(oldPath)) {
      try {
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
      } catch (_) {}
    }

    final updatedProfile = _profile!.copyWith(avatarPath: newPath);
    await DatabaseHelper.instance.updateProfile(updatedProfile);

    if (mounted) {
      setState(() {
        _profile = updatedProfile;
      });
    }
  }

  Future<void> _openEditor() async {
    if (_profile == null) return;

    // 👇 НОВОЕ: запоминаем хеш до редактирования
    final hashBefore = _computeProfileHash(_profile!);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: _profile),
      ),
    );

    if (result == true) {
      await _loadProfile();

      final profiles = await DatabaseHelper.instance.getProfiles();
      if (profiles.isEmpty) return;

      final updated = await _resolveActiveProfile(profiles);
      if (updated == null) return;

      await FairyReactionService().setActiveProfile(
        updated.id,
        updated.name,
        gender: updated.gender,
      );

      // 👇 ИЗМЕНЕНО: триггерим «профиль изменён» только при реальной смене
      // значимых для плана полей. Открыл-закрыл редактор без правок — фея молчит.
      // Основную подсказку об обновлении плана всё равно ведёт хеш
      // в WorkoutScreen._shouldSuggestPlanUpdate, здесь — страховочный пуш.
      if (_computeProfileHash(updated) != hashBefore) {
        FairyReactionService().trigger(
          'profile_changed_ask',
          nameOverride: updated.name,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? _buildEmptyState(context)
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(context, _profile!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openEditor,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Редактировать профиль'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.person_add_rounded,
                size: 60,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Нет профиля', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Создайте профиль,\nчтобы начать тренировки',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen(),
                  ),
                );
                if (result == true) {
                  await _loadProfile();

                  // ⚠️ Событие: профиль СОЗДАН
                  final profiles = await DatabaseHelper.instance.getProfiles();
                  if (profiles.isNotEmpty && mounted) {
                    FairyReactionService().trigger(
                      'profile_created',
                      nameOverride: profiles.first.name,
                    );
                  }
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Создать профиль'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: _avatarImageProvider(profile.avatarPath),
                child: _avatarImageProvider(profile.avatarPath) == null
                    ? Text(
                  profile.name.isNotEmpty
                      ? profile.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            _infoRow(context, Icons.person_rounded, profile.genderLabel),
            _infoRow(context, Icons.cake_rounded, '${profile.age} лет'),
            _infoRow(context, Icons.flag_rounded, profile.goalLabel),
            _infoRow(context, Icons.fitness_center_rounded,
                profile.equipmentLabel),
            _infoRow(context, Icons.calendar_today_rounded,
                '${profile.daysPerWeek} дней в неделю'),
            // 👇 Выбранные дни тренировок («Вт, Пт» или «Не выбрано»)
            _infoRow(context, Icons.event_available_rounded,
                profile.trainingWeekdaysLabel),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
