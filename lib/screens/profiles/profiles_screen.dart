import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/database_helper.dart';
import '../../services/fairy_reaction_service.dart';
import 'profile_edit_screen.dart';

/// Экран «Профили».
///
/// Один профиль — без списка, без «+ Создать», без удаления.
/// Доступно только редактирование.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    var profiles = await DatabaseHelper.instance.getProfiles();

    // ═══ RETRY: ждём, пока база откроется (Web) ═══
    if (profiles.isEmpty) {
      for (int attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(const Duration(milliseconds: 300));
        profiles = await DatabaseHelper.instance.getProfiles();
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

    final active = profiles.first;

    // ═══ Сообщаем фее, кто активный ═══
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

  Future<void> _openEditor() async {
    if (_profile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: _profile),
      ),
    );

    if (result == true) {
      await _loadProfile();

      // ═══ Реакция феи ═══
      final profiles = await DatabaseHelper.instance.getProfiles();
      if (profiles.isEmpty) return;

      final updated = profiles.first;
      await FairyReactionService().setActiveProfile(
        updated.id,
        updated.name,
        gender: updated.gender,
      );
      FairyReactionService().trigger(
        'profile_updated',
        nameOverride: updated.name,
      );
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
                    theme.colorScheme.primary.withOpacity(0.15),
                    theme.colorScheme.primary.withOpacity(0.05),
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                if (result == true) _loadProfile();
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  profile.name.isNotEmpty
                      ? profile.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}