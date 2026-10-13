import 'package:flutter/material.dart';
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
  List<UserProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
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

    // ═══ Сообщаем фее, кто активный ═══
    if (profiles.isNotEmpty) {
      await FairyReactionService().loadActiveProfile();
      final activeId = FairyReactionService().activeProfileId;

      final active = profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => profiles.first,
      );

      await FairyReactionService().setActiveProfile(
        active.id,
        active.name,
        gender: active.gender,
      );
    } else {
      await FairyReactionService().setActiveProfile(null, null);
    }

    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _openEditor({UserProfile? profile}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: profile),
      ),
    );
    if (result == true) {
      await _loadProfiles();

      // ═══ Реакция феи с правильным именем и родом ═══
      final profiles = await DatabaseHelper.instance.getProfiles();
      if (profiles.isEmpty) return;

      if (profile != null) {
        final updated = profiles.firstWhere(
          (p) => p.id == profile.id,
          orElse: () => profiles.first,
        );
        await FairyReactionService().setActiveProfile(
          updated.id,
          updated.name,
          gender: updated.gender,
        );
        FairyReactionService().trigger(
          'profile_updated',
          nameOverride: updated.name,
        );
      } else {
        final newProfile = profiles.first;
        await FairyReactionService().setActiveProfile(
          newProfile.id,
          newProfile.name,
          gender: newProfile.gender,
        );
        FairyReactionService().trigger(
          'profile_created',
          nameOverride: newProfile.name,
        );
      }
    }
  }

  Future<void> _deleteProfile(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: Text('Профиль «${profile.name}» будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteProfile(profile.id!);
      await _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профили'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Создать профиль',
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadProfiles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _profiles.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProfileCard(context, _profiles[i]),
                    ),
                  ),
                ),
      floatingActionButton: _profiles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Профиль'),
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
            Text('Нет профилей', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Создайте первый профиль,\nчтобы начать тренировки',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _openEditor(),
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
      child: InkWell(
        onTap: () => _openEditor(profile: profile),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.genderLabel} · ${profile.age} лет · ${profile.goalLabel}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.equipmentLabel} · ${profile.daysPerWeek} дн/нед',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: theme.colorScheme.error,
                onPressed: () => _deleteProfile(profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}